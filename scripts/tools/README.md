# scripts/tools

Outillage **hôte** du dépôt — lancé à la main sur la machine du mainteneur, **jamais embarqué dans l'image** (le `Dockerfile` ne copie que `scripts/runtime/`). Les deux scripts partagent la **même matrice de versions** (tableau `STEPS`, `gs_version|base_image|jetty_version|servlet_profile`), source unique de vérité de la gamme GeoServer 2.17.5 → 3.0.0.

| Script | Rôle | Effet |
|---|---|---|
| [`migrate.sh`](./migrate.sh) | Migration d'un data dir (staircase 2.16.4 → 3.0.0) | fait **booter** chaque palier sur un même data dir |
| [`build-and-push.sh`](./build-and-push.sh) | Backfill Docker Hub de toute la gamme | **build + push** chaque image |

> Prérequis communs : `docker`, et l'image de base **Java 11** `allfab/gdal-ecw:java11` présente localement pour les paliers 2.17 → 2.27 (construite depuis le dépôt `gdal-ecw-docker`). La base Java 21 est `allfab/gdal-ecw:latest`.

---

## `migrate.sh` — migration progressive du data dir

Charge un **même data dir** par chaque version mineure successive (staircase) pour appliquer, dans l'ordre, les migrations de boot de GeoServer. À chaque palier : snapshot de l'état d'entrée → démarrage du conteneur (HTTPS off, data dir monté) → attente que `/geoserver/web/` réponde `200` → arrêt gracieux → résumé WARN/ERROR.

Données de travail sous `migration/` (git-ignoré) : `src/config` (data dir 2.16.4 d'origine, **jamais modifié**), `work/config` (copie mutée palier par palier), `steps/` (snapshots d'entrée), `logs/`.

⚠️ **Ne jamais** passer `GEOSERVER_ADMIN_USER` / `GEOSERVER_ADMIN_PASSWORD` : cela écraserait le compte existant du data dir.

### Lancement

```bash
# Build + run de chaque palier (repart d'un data dir frais)
BUILD=1 ./scripts/tools/migrate.sh

# Images déjà présentes : run seul
./scripts/tools/migrate.sh

# Reprise à partir d'un palier (1-based) sur la copie de travail existante
START_STEP=8 ./scripts/tools/migrate.sh
```

### Variables

| Variable | Défaut | Rôle |
|---|---|---|
| `START_STEP` | `1` | palier de départ (1-based) |
| `BUILD` | `0` | `1` = build l'image du palier avant de la lancer |
| `FRESH` | `0` | `1` = ré-initialise `work/config` depuis la source (implicite si `START_STEP=1`) |
| `PORT` | `8080` | port hôte exposé |
| `READY_TIMEOUT` | `600` | secondes max d'attente du `200` sur `/geoserver/web/` |
| `SETTLE_SECONDS` | `15` | pause après `200` (flush des écritures) |
| `STOP_TIMEOUT` | `40` | délai d'arrêt gracieux Jetty |
| `IMAGE_PREFIX` | `allfab/geoserver-ecw` | préfixe des images |
| `JAVA11_BASE` / `JAVA21_BASE` | `…:java11` / `…:latest` | images de base par tier |
| `JETTY10` / `JETTY12` | `10.0.24` / `12.1.7` | versions Jetty par tier |

> La sonde de disponibilité utilise `curl -L -b /dev/null` : dès 2.21 `/geoserver/web/` répond `302` vers une URL chiffrée (CryptoMapper Wicket) et dès 2.24 le `JSESSIONID` est requis — sans suivi de redirection ni renvoi du cookie, la sonde reboucle (faux négatif au boot).

À la fin, le data dir final `migration/work/config` est en 3.0.0 : démarrer l'image ECW complète 3.0.0 dessus, vérifier la console + un GetMap ECW.

---

## `build-and-push.sh` — backfill Docker Hub

Opération **ponctuelle** : build + push vers Docker Hub de **chaque** image de la gamme. À la différence de `migrate.sh`, il ne fait **pas** booter les images ; il enchaîne, par palier, `build → push → (option) rmi`. Au quotidien c'est le pipeline Woodpecker (`.woodpecker/.build.yml`) qui publie l'image courante (`latest` / `3.0.0`) ; ce script sert à (re)publier l'historique complet.

### Tags produits par palier

- `allfab/geoserver-ecw:<version>` — ex. `2.28.4`
- `allfab/geoserver-ecw:<version>-<debian>-slim` — ex. `2.28.4-13.6-slim`, la version Debian étant **lue dans `/etc/debian_version` de l'image de base** (elle dépend du `BASE_IMAGE`, pas de la version GeoServer). Omis proprement si la base ne renvoie pas un `NN.N` numérique.
- `allfab/geoserver-ecw:latest` — **uniquement** pour la version de référence (`LATEST_VERSION`, `3.0.0`).

### Lancement

```bash
# Backfill complet des 13 versions (login non-interactif via variables)
DOCKER_USER=allfab DOCKER_PASS=****** ./scripts/tools/build-and-push.sh

# Reprise après échec au palier 8
START_STEP=8 ./scripts/tools/build-and-push.sh

# Répétition à blanc : build local sans push
PUSH=0 ./scripts/tools/build-and-push.sh

# Disque serré : purge chaque image locale après son push
PRUNE=1 DOCKER_USER=allfab DOCKER_PASS=****** ./scripts/tools/build-and-push.sh
```

> Opération longue (jusqu'à 13 builds `--no-cache`, chacun télécharge WAR + plugin GDAL + Jetty) : la lancer en `tmux` / arrière-plan.

### Variables

| Variable | Défaut | Rôle |
|---|---|---|
| `START_STEP` | `1` | palier de départ (1-based) |
| `NO_CACHE` | `1` | `1` = `docker build --no-cache` (backfill propre) |
| `PUSH` | `1` | `0` = build seul, aucun push (dry run local) |
| `PRUNE` | `0` | `1` = `docker rmi` l'image après son push |
| `LATEST_VERSION` | `3.0.0` | version portant aussi le tag `:latest` |
| `DOCKER_USER` / `DOCKER_PASS` | — | login Docker Hub non-interactif (sinon on suppose déjà loggué) |
| `IMAGE_PREFIX` | `allfab/geoserver-ecw` | préfixe des images |
| `JAVA11_BASE` / `JAVA21_BASE` | `…:java11` / `…:latest` | images de base par tier |
| `JETTY10` / `JETTY12` | `10.0.24` / `12.1.7` | versions Jetty par tier |

---

## Faire évoluer la gamme

La liste des versions vit dans le tableau `STEPS` de **chaque** script (volontairement dupliqué pour garder les outils autonomes). Pour ajouter/retirer un palier, éditer `STEPS` dans les deux scripts en respectant le format `gs_version|base_image|jetty_version|servlet_profile` et la matrice de profils runtime (cf. `CLAUDE.md` / `MIGRATION.md`).
