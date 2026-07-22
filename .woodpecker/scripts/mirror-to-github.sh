#!/bin/bash
# mirror-to-github.sh — miroir filtré Forgejo → GitHub.
#
# Clone le repo Forgejo source en miroir dans un dossier éphémère, retire
# les chemins non-publics de l'historique avec git filter-repo, puis pousse
# en mode miroir (atomique) vers le remote GitHub public.
#
# Variables d'env requises :
#   SOURCE_REPO_URL      URL HTTPS du repo Forgejo sans credentials
#                        (ex. https://forgejo.allfabox.fr/allfab/geoserver-ecw-docker.git)
#   FORGEJO_TOKEN        token Forgejo lecture seule pour cloner la source
#                        (tant que le repo reste privé interne)
#   GITHUB_MIRROR_TOKEN  fine-grained PAT GitHub (Contents: Read and write)
#                        scope limité à TARGET_REPO
#   TARGET_REPO          ex. vienne-condrieu-agglomeration/geoserver-ecw-docker
#
# Variables d'env optionnelles :
#   WORK_DIR             dossier de travail (défaut : /tmp/mirror-work)
#   FORGEJO_USER         user Forgejo pour l'auth HTTP basic (défaut : oauth2)
#
# Sécurité : aucun token n'apparaît dans les URLs des remotes ni dans la
# sortie de `git push`. L'authentification GitHub passe par `http.extraheader`
# éphémère, limité à la commande concernée.
#
# Exécuté par .woodpecker/mirror-github.yml sur image python:3.12-slim
# (git, ca-certificates et git-filter-repo installés en amont).
set -euo pipefail

: "${SOURCE_REPO_URL:?SOURCE_REPO_URL manquant}"
: "${TARGET_REPO:?TARGET_REPO manquant}"
if [ -z "${GITHUB_MIRROR_TOKEN:-}" ]; then
  echo "❌ GITHUB_MIRROR_TOKEN vide — refus d'exécution" >&2
  exit 1
fi
if [ -z "${FORGEJO_TOKEN:-}" ]; then
  echo "❌ FORGEJO_TOKEN vide — refus d'exécution (repo source privé)" >&2
  exit 1
fi

WORK_DIR="${WORK_DIR:-/tmp/mirror-work}"
FORGEJO_USER="${FORGEJO_USER:-oauth2}"

# Chemins exclus de l'historique public.
# `CLAUDE.md` : directives agent IA locales, non pertinentes pour le miroir
# public. Retiré de TOUT l'historique (aucun commit ne l'expose sur GitHub).
# Pour exclure un futur chemin exact, l'ajouter à cette liste.
EXCLUDED_PATHS="
CLAUDE.md
"

# Globs exclus de l'historique public (vide ici : contrairement à
# gdal-ecw-docker, ce dépôt n'embarque pas le SDK propriétaire Hexagon et
# n'a aucun fichier > 100 Mo). Mécanisme conservé pour extension future.
EXCLUDED_GLOBS="
"

echo "=== Nettoyage du répertoire de travail ==="
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"

echo "=== Clone miroir depuis $SOURCE_REPO_URL ==="
# Auth Forgejo via credentials dans l'URL, scope limité au seul `git clone`.
# Le token n'est pas persisté : `git filter-repo` retire le remote `origin`
# plus bas, et on ne log jamais CLONE_URL.
SOURCE_HOST_PATH="${SOURCE_REPO_URL#https://}"
CLONE_URL="https://${FORGEJO_USER}:${FORGEJO_TOKEN}@${SOURCE_HOST_PATH}"
git clone --mirror "$CLONE_URL" "$WORK_DIR/repo.git"
unset CLONE_URL

cd "$WORK_DIR/repo.git"

echo "=== Filtrage des chemins exclus ==="
FILTER_ARGS=()
for p in $EXCLUDED_PATHS; do
  echo "  - path: $p"
  FILTER_ARGS+=(--path "$p")
done
for g in $EXCLUDED_GLOBS; do
  echo "  - glob: $g"
  FILTER_ARGS+=(--path-glob "$g")
done

git filter-repo --force --invert-paths "${FILTER_ARGS[@]}"

echo "=== Configuration du remote GitHub (URL sans token) ==="
# git filter-repo retire le remote origin : on le recrée vers GitHub *sans*
# inclure le token dans l'URL, pour ne jamais le logger en cas d'erreur.
REMOTE_URL="https://github.com/${TARGET_REPO}.git"
git remote remove origin 2>/dev/null || true
git remote add origin "$REMOTE_URL"

echo "=== Push miroir atomique (branches + tags + suppressions) ==="
# --mirror : une seule transaction, pousse refs/* (y compris tags), et
# supprime côté GitHub les branches/tags qui n'existent plus côté source.
# Auth via extraheader Basic uniquement pour cette commande : GitHub HTTPS
# git n'accepte pas Bearer, il faut Basic avec user=x-access-token.
GITHUB_BASIC=$(printf '%s:%s' "x-access-token" "$GITHUB_MIRROR_TOKEN" | base64 -w0)
git -c "http.extraheader=Authorization: Basic $GITHUB_BASIC" \
    push --mirror --force origin

echo "=== Miroir synchronisé vers $TARGET_REPO ==="
