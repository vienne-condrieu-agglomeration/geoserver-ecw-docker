#!/bin/bash
#
# build-and-push.sh
#
# Build + push vers Docker Hub de CHAQUE image GeoServer-ECW de la gamme
# (2.17.5 -> 3.0.0), en reutilisant la meme matrice de versions que migrate.sh.
#
# A la difference de migrate.sh (qui fait boot chaque palier sur un data dir
# partage), ce script ne fait que : build image -> docker push -> (option) rmi.
# C'est une operation PONCTUELLE de backfill : au quotidien, c'est le pipeline
# Woodpecker qui publie l'image courante (latest / 3.0.0).
#
# (c) Allfab 2026 <allfab@gmail.com>

set -euo pipefail

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_PREFIX="${IMAGE_PREFIX:-allfab/geoserver-ecw}"

# La version portant aussi le tag :latest (doit correspondre a la CI).
LATEST_VERSION="${LATEST_VERSION:-3.0.0}"

# Images de base et versions Jetty par tier (identiques a migrate.sh)
JAVA11_BASE="${JAVA11_BASE:-allfab/gdal-ecw:java11}"
JAVA21_BASE="${JAVA21_BASE:-allfab/gdal-ecw:latest}"
JETTY10="${JETTY10:-10.0.24}"
JETTY12="${JETTY12:-12.1.7}"

# Matrice : "gs_version|base_image|jetty_version|servlet_profile"
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
  "3.0.0|${JAVA21_BASE}|${JETTY12}|jetty12-ee11"
)

# Options :
#   START_STEP=<n>  reprendre a partir du palier n (1-based). Defaut : 1.
#   NO_CACHE=1      build --no-cache (recommande pour un backfill propre). Defaut : 1.
#   PUSH=1          pousser apres build. Defaut : 1. (PUSH=0 = build seul, dry run local)
#   PRUNE=1         docker rmi l'image apres push (economise le disque). Defaut : 0.
#   DOCKER_USER / DOCKER_PASS : login non-interactif (sinon on suppose deja loggue).
START_STEP="${START_STEP:-1}"
NO_CACHE="${NO_CACHE:-1}"
PUSH="${PUSH:-1}"
PRUNE="${PRUNE:-0}"

# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------
log()  { echo -e "\033[1;33m[build-push]\033[0m $*"; }
ok()   { echo -e "\033[0;32m[build-push]\033[0m $*"; }
err()  { echo -e "\033[0;31m[build-push]\033[0m $*" >&2; }

# Deduit le suffixe Debian du tag -slim (ex. "13.6") en lisant /etc/debian_version
# DANS l'image de base : la version Debian depend du BASE_IMAGE, pas de la version
# GeoServer. Renvoie une chaine vide si illisible (on saute alors le tag -slim).
debian_tag() {
  local base="$1" deb
  deb="$(docker run --rm --entrypoint cat "${base}" /etc/debian_version 2>/dev/null | tr -d '[:space:]')"
  # On ne garde que les versions numeriques stables (ex. 13.6), pas "trixie/sid".
  if [[ "${deb}" =~ ^[0-9]+\.[0-9]+$ ]]; then
    echo "${deb}"
  else
    echo ""
  fi
}

build_one() {
  local gs="$1" base="$2" jetty="$3" profile="$4"
  local cache_flag=()
  [ "${NO_CACHE}" = "1" ] && cache_flag=(--no-cache)

  # Tags : version pleine + latest si c'est la version de reference.
  local tags=(-t "${IMAGE_PREFIX}:${gs}")
  if [ "${gs}" = "${LATEST_VERSION}" ]; then
    tags+=(-t "${IMAGE_PREFIX}:latest")
  fi

  # Tag -slim : <gs>-<debian>-slim (ex. 3.0.0-13.6-slim), Debian lu dans la base.
  SLIM_TAG=""
  local deb
  deb="$(debian_tag "${base}")"
  if [ -n "${deb}" ]; then
    SLIM_TAG="${gs}-${deb}-slim"
    tags+=(-t "${IMAGE_PREFIX}:${SLIM_TAG}")
    log "Suffixe -slim deduit : ${SLIM_TAG} (Debian ${deb} de ${base})"
  else
    err "Version Debian illisible dans ${base} : tag -slim omis pour ${gs}."
  fi

  log "Build ${IMAGE_PREFIX}:${gs} (base=${base}, jetty=${jetty}, profile=${profile})"
  docker build -f "${REPO_DIR}/Dockerfile" "${cache_flag[@]}" \
    --build-arg BASE_IMAGE="${base}" \
    --build-arg GS_VERSION="${gs}" \
    --build-arg JETTY_VERSION="${jetty}" \
    --build-arg SERVLET_PROFILE="${profile}" \
    --build-arg BUILD_DATE="$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
    "${tags[@]}" \
    "${REPO_DIR}"
}

push_one() {
  local gs="$1"
  log "Push ${IMAGE_PREFIX}:${gs}"
  docker push "${IMAGE_PREFIX}:${gs}"
  if [ -n "${SLIM_TAG:-}" ]; then
    log "Push ${IMAGE_PREFIX}:${SLIM_TAG}"
    docker push "${IMAGE_PREFIX}:${SLIM_TAG}"
  fi
  if [ "${gs}" = "${LATEST_VERSION}" ]; then
    log "Push ${IMAGE_PREFIX}:latest"
    docker push "${IMAGE_PREFIX}:latest"
  fi
}

prune_one() {
  local gs="$1"
  log "Prune images locales ${IMAGE_PREFIX}:${gs}"
  docker rmi --force "${IMAGE_PREFIX}:${gs}" >/dev/null 2>&1 || true
  [ -n "${SLIM_TAG:-}" ] && docker rmi --force "${IMAGE_PREFIX}:${SLIM_TAG}" >/dev/null 2>&1 || true
  if [ "${gs}" = "${LATEST_VERSION}" ]; then
    docker rmi --force "${IMAGE_PREFIX}:latest" >/dev/null 2>&1 || true
  fi
}

# ------------------------------------------------------------------------------
# Pre-vol
# ------------------------------------------------------------------------------
command -v docker >/dev/null || { err "docker introuvable"; exit 1; }

if [ "${PUSH}" = "1" ] && [ -n "${DOCKER_USER:-}" ] && [ -n "${DOCKER_PASS:-}" ]; then
  log "Login Docker Hub (${DOCKER_USER})"
  echo "${DOCKER_PASS}" | docker login docker.io --username "${DOCKER_USER}" --password-stdin
fi

# ------------------------------------------------------------------------------
# Boucle des paliers
# ------------------------------------------------------------------------------
idx=0
built=()
for entry in "${STEPS[@]}"; do
  idx=$(( idx + 1 ))
  [ "${idx}" -lt "${START_STEP}" ] && continue
  IFS='|' read -r gs base jetty profile <<< "${entry}"

  log "=== Palier ${idx}/${#STEPS[@]} : GeoServer ${gs} ==="
  build_one "${gs}" "${base}" "${jetty}" "${profile}"
  [ "${PUSH}"  = "1" ] && push_one  "${gs}"
  [ "${PRUNE}" = "1" ] && prune_one "${gs}"
  built+=("${gs}")
  ok "Palier ${gs} termine."
done

ok "Termine. Images traitees : ${built[*]}"
[ "${PUSH}" = "1" ] && ok "Toutes poussees vers Docker Hub (${IMAGE_PREFIX})." || ok "Mode build-only (PUSH=0), rien n'a ete pousse."
