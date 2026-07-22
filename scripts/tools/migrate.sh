#!/bin/bash
#
# migrate.sh
#
# Migration progressive d'un data dir GeoServer 2.16.4 -> 3.0.0 (staircase complet).
# Chaque version mineure charge successivement le MEME data dir pour appliquer,
# dans l'ordre, ses migrations de boot. Voir le plan et README/BUILD pour le detail.
#
# (c) Allfab 2026 <allfab@gmail.com>

set -euo pipefail

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MIGRATION_DIR="${REPO_DIR}/migration"
SRC_DIR="${MIGRATION_DIR}/src/config"       # data dir 2.16.4 d'origine (jamais modifie)
WORK_DIR="${MIGRATION_DIR}/work/config"      # copie de travail (mutee palier par palier)
STEPS_DIR="${MIGRATION_DIR}/steps"           # snapshots de l'etat d'ENTREE de chaque palier
LOGS_DIR="${MIGRATION_DIR}/logs"             # logs docker par palier

CONTAINER="gs-migrate"
PORT="${PORT:-8080}"
IMAGE_PREFIX="${IMAGE_PREFIX:-allfab/geoserver-ecw}"
READY_TIMEOUT="${READY_TIMEOUT:-600}"        # secondes max pour attendre /geoserver/web/
SETTLE_SECONDS="${SETTLE_SECONDS:-15}"       # pause apres HTTP 200, laisse flush les ecritures
STOP_TIMEOUT="${STOP_TIMEOUT:-40}"           # arret gracieux Jetty

# Images de base et versions Jetty par tier
JAVA11_BASE="${JAVA11_BASE:-allfab/gdal-ecw:java11}"
JAVA21_BASE="${JAVA21_BASE:-allfab/gdal-ecw:latest}"
JETTY10="${JETTY10:-10.0.24}"
JETTY12="${JETTY12:-12.1.7}"

# Matrice : "gs_version|base_image|jetty_version|servlet_profile"
# (le 2.16.4 est la SOURCE, pas un palier a jouer)
STEPS=(
  "2.17.5|${JAVA11_BASE}|${JETTY10}|jetty10-javax"
  "2.18.7|${JAVA11_BASE}|${JETTY10}|jetty10-javax"
  "2.19.7|${JAVA11_BASE}|${JETTY10}|jetty10-javax"
  "2.20.7|${JAVA11_BASE}|${JETTY10}|jetty10-javax"
  "2.21.5|${JAVA11_BASE}|${JETTY10}|jetty10-javax"
  "2.22.6|${JAVA11_BASE}|${JETTY10}|jetty10-javax"
  "2.23.6|${JAVA11_BASE}|${JETTY10}|jetty10-javax"
  "2.24.5|${JAVA11_BASE}|${JETTY10}|jetty10-javax"
  "2.25.7|${JAVA11_BASE}|${JETTY10}|jetty10-javax"
  "2.26.4|${JAVA11_BASE}|${JETTY10}|jetty10-javax"
  "2.27.5|${JAVA11_BASE}|${JETTY10}|jetty10-javax"
  "2.28.4|${JAVA21_BASE}|${JETTY12}|jetty12-ee8"
  # GeoServer 3.0 = Jakarta Servlet 6.1 = EE11 -> modules Jetty ee11 (raison du besoin de Jetty 12.1).
  # Si le WAR 3.0 s'avere en Servlet 6.0/EE10, basculer sur jetty12-ee10.
  "3.0.0|${JAVA21_BASE}|${JETTY12}|jetty12-ee11"
)

# Options :
#   START_STEP=<n>  reprendre a partir du palier n (1-based). Defaut : 1.
#   BUILD=1         construire l'image du palier avant de la lancer (sinon on suppose qu'elle existe).
#   FRESH=1         re-initialiser WORK_DIR depuis SRC_DIR avant de demarrer (implicite si START_STEP=1).
START_STEP="${START_STEP:-1}"
BUILD="${BUILD:-0}"
FRESH="${FRESH:-0}"

# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------
log()  { echo -e "\033[1;33m[migrate]\033[0m $*"; }
ok()   { echo -e "\033[0;32m[migrate]\033[0m $*"; }
err()  { echo -e "\033[0;31m[migrate]\033[0m $*" >&2; }

cleanup_container() {
  docker rm -f "${CONTAINER}" >/dev/null 2>&1 || true
}
trap cleanup_container EXIT

build_image() {
  local gs="$1" base="$2" jetty="$3" profile="$4"
  log "Build ${IMAGE_PREFIX}:${gs} (base=${base}, jetty=${jetty}, profile=${profile})"
  docker build -f "${REPO_DIR}/Dockerfile" \
    --build-arg BASE_IMAGE="${base}" \
    --build-arg GS_VERSION="${gs}" \
    --build-arg JETTY_VERSION="${jetty}" \
    --build-arg SERVLET_PROFILE="${profile}" \
    --build-arg BUILD_DATE="$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
    -t "${IMAGE_PREFIX}:${gs}" \
    "${REPO_DIR}"
}

wait_ready() {
  local deadline=$(( SECONDS + READY_TIMEOUT ))
  local code=""
  while [ "${SECONDS}" -lt "${deadline}" ]; do
    if ! docker ps --format '{{.Names}}' | grep -qx "${CONTAINER}"; then
      err "Le conteneur ${CONTAINER} s'est arrete de facon inattendue."
      return 1
    fi
    # -L + moteur de cookies (-b /dev/null, en memoire) : depuis 2.21,
    # /geoserver/web/ repond 302 vers une URL chiffree (CryptoMapper,
    # ?wicket-crypt=...). Depuis 2.24 le JSESSIONID est HttpOnly et REQUIS sur
    # l'URL chiffree : sans renvoi du cookie, la redirection reboucle (302 x50).
    # -b /dev/null active le renvoi du cookie ; le code final (200) est uniforme
    # pour tous les paliers (2.17->2.20 en 200 direct, 2.21+ en 302->200).
    code="$(curl -s -L -b /dev/null -o /dev/null -w '%{http_code}' "http://localhost:${PORT}/geoserver/web/" 2>/dev/null || true)"
    if [ "${code}" = "200" ]; then
      return 0
    fi
    sleep 5
  done
  err "Timeout (${READY_TIMEOUT}s) : /geoserver/web/ n'a pas repondu 200 (dernier code: ${code:-none})."
  return 1
}

run_step() {
  local idx="$1" gs="$2" base="$3" jetty="$4" profile="$5"
  local tag="${IMAGE_PREFIX}:${gs}"
  local logfile="${LOGS_DIR}/$(printf '%02d' "${idx}")-${gs}.log"
  local snap="${STEPS_DIR}/$(printf '%02d' "${idx}")-${gs}"

  log "=== Palier ${idx} : GeoServer ${gs} ==="

  if [ "${BUILD}" = "1" ]; then
    build_image "${gs}" "${base}" "${jetty}" "${profile}"
  fi
  if ! docker image inspect "${tag}" >/dev/null 2>&1; then
    err "Image ${tag} absente. Construis-la (BUILD=1) ou fournis-la avant de lancer ce palier."
    return 1
  fi

  # Snapshot de l'etat d'ENTREE (permet de reprendre ce palier proprement)
  log "Snapshot etat d'entree -> ${snap}/config"
  mkdir -p "${snap}"
  rm -rf "${snap}/config"
  cp -a "${WORK_DIR}" "${snap}/config"

  cleanup_container
  log "Demarrage ${tag} (data dir partage, HTTPS off, port ${PORT})"
  # IMPORTANT : ne PAS passer GEOSERVER_ADMIN_USER/PASSWORD (ecraserait le compte 'igeo').
  #             INSTALL_EXTENSIONS reste false (aucune extension sur cette config).
  docker run -d --name "${CONTAINER}" \
    -e HTTPS_ENABLED=false \
    -v "${WORK_DIR}:/app/geoserver/config" \
    -p "${PORT}:8080" \
    "${tag}" >/dev/null

  if wait_ready; then
    ok "GeoServer ${gs} operationnel. Pause ${SETTLE_SECONDS}s (flush)."
    sleep "${SETTLE_SECONDS}"
  else
    docker logs "${CONTAINER}" > "${logfile}" 2>&1 || true
    err "Echec du palier ${gs}. Logs -> ${logfile}"
    err "Etat d'entree conserve dans ${snap}/config (restaure-le dans work/config pour rejouer)."
    return 1
  fi

  log "Arret gracieux (${STOP_TIMEOUT}s)"
  docker logs "${CONTAINER}" > "${logfile}" 2>&1 || true
  docker stop -t "${STOP_TIMEOUT}" "${CONTAINER}" >/dev/null 2>&1 || true
  cleanup_container

  # Resume des WARN/ERROR de migration
  local nerr nwarn
  nerr="$(grep -c -iE '\bERROR\b'   "${logfile}" 2>/dev/null || true)"
  nwarn="$(grep -c -iE '\bWARN(ING)?\b' "${logfile}" 2>/dev/null || true)"
  ok "Palier ${gs} termine. (${nerr:-0} ERROR / ${nwarn:-0} WARN dans ${logfile})"
}

# ------------------------------------------------------------------------------
# Pre-vol
# ------------------------------------------------------------------------------
command -v docker >/dev/null || { err "docker introuvable"; exit 1; }
command -v curl   >/dev/null || { err "curl introuvable"; exit 1; }
[ -d "${SRC_DIR}" ] || { err "Source absente : ${SRC_DIR}"; exit 1; }

mkdir -p "${STEPS_DIR}" "${LOGS_DIR}" "$(dirname "${WORK_DIR}")"

if [ "${START_STEP}" -le 1 ] || [ "${FRESH}" = "1" ]; then
  log "Initialisation de la copie de travail depuis la source 2.16.4"
  rm -rf "${WORK_DIR}"
  cp -a "${SRC_DIR}" "${WORK_DIR}"
else
  [ -d "${WORK_DIR}" ] || { err "START_STEP=${START_STEP} mais aucune copie de travail (${WORK_DIR}). Lance FRESH=1 ou START_STEP=1."; exit 1; }
  log "Reprise sur copie de travail existante a partir du palier ${START_STEP}"
fi

# ------------------------------------------------------------------------------
# Boucle des paliers
# ------------------------------------------------------------------------------
idx=0
for entry in "${STEPS[@]}"; do
  idx=$(( idx + 1 ))
  [ "${idx}" -lt "${START_STEP}" ] && continue
  IFS='|' read -r gs base jetty profile <<< "${entry}"
  run_step "${idx}" "${gs}" "${base}" "${jetty}" "${profile}"
done

ok "Migration terminee. Data dir final (3.0.0) : ${WORK_DIR}"
ok "Etapes suivantes : demarrer l'image ECW complete 3.0.0 sur ce data dir, verifier la console + un GetMap ECW."
