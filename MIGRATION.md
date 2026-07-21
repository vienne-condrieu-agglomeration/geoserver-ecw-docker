# Migration d'un data dir GeoServer 2.16.4 → 3.0.0

Ce document décrit la procédure de migration progressive d'un répertoire de
configuration (data dir) GeoServer **2.16.4** (2019) jusqu'à **3.0.0**, à l'aide
des images ECW construites depuis ce dépôt.

## Pourquoi une migration « en escalier »

GeoServer applique ses migrations de data dir **au démarrage** de chaque version.
Un saut direct 2.16 → 3.0 (≈ 12 versions mineures, 6 ans) n'est ni testé ni
fiable. On fait donc charger le **même data dir** par chaque version mineure
successive (*staircase*), pour que chacune applique ses mises à niveau de boot
dans l'ordre. Il n'est **pas** nécessaire de ré-exécuter 2.16 : le data dir
existe déjà, on part de 2.17.

## Deux contraintes qui dictent l'architecture

1. **Runtime Java.** GeoServer 2.16 tourne sur Java 8/11 ; 2.28+ et 3.0 exigent
   **Java 17+**. L'image de base `allfab/gdal-ecw` n'embarque que Java 21 → il faut
   un second variant en **Java 11** pour les vieilles versions.
2. **Jetty / namespace servlet.** Jetty 12 exige Java 17+ ; on utilise donc
   **Jetty 10** (javax, Java 11+) pour le tier ancien. GeoServer 2.x = `javax.servlet`
   (modules `ee8-*` sur Jetty 12) ; **GeoServer 3.0 = Jakarta Servlet 6.1 / EE11**
   → modules `ee11-*`, disponibles seulement à partir de **Jetty 12.1** (d'où
   l'exigence de cette version précise).

## Matrice des paliers

| Étape | GeoServer | Image de base | Java | Jetty | `SERVLET_PROFILE` |
|---|---|---|---|---|---|
| src | 2.16.4 | — | — | — | — (source) |
| 1 | 2.17.5 | `allfab/gdal-ecw:java11` | 11 | 10.0.x | `jetty10-javax` |
| 2 | 2.18.7 | `allfab/gdal-ecw:java11` | 11 | 10.0.x | `jetty10-javax` |
| 3 | 2.19.7 | `allfab/gdal-ecw:java11` | 11 | 10.0.x | `jetty10-javax` |
| 4 | 2.20.7 | `allfab/gdal-ecw:java11` | 11 | 10.0.x | `jetty10-javax` |
| 5 | 2.21.5 | `allfab/gdal-ecw:java11` | 11 | 10.0.x | `jetty10-javax` |
| 6 | 2.22.6 | `allfab/gdal-ecw:java11` | 11 | 10.0.x | `jetty10-javax` |
| 7 | 2.23.6 | `allfab/gdal-ecw:java11` | 11 | 10.0.x | `jetty10-javax` |
| 8 | 2.24.5 | `allfab/gdal-ecw:java11` | 11 | 10.0.x | `jetty10-javax` |
| 9 | 2.25.7 | `allfab/gdal-ecw:java11` | 11 | 10.0.x | `jetty10-javax` |
| 10 | 2.26.4 | `allfab/gdal-ecw:java11` | 11 | 10.0.x | `jetty10-javax` |
| 11 | 2.27.5 | `allfab/gdal-ecw:java11` | 11 | 10.0.x | `jetty10-javax` |
| 12 | 2.28.4 | `allfab/gdal-ecw:latest` | 21 | 12.1.x | `jetty12-ee8` |
| 13 | 3.0.0 | `allfab/gdal-ecw:latest` | 21 | 12.1.x | `jetty12-ee11` |

> Les numéros sont les derniers patchs publiés sur SourceForge à la date de
> rédaction. La matrice est définie dans `migrate.sh` (tableau `STEPS`).

## Paramétrage du dépôt (fait dans cette session)

- **`Dockerfile`** — généralisé par build-args :
  - `BASE_IMAGE` : `allfab/gdal-ecw:java11` ou `:latest`.
  - `GS_VERSION` : version GeoServer du palier.
  - `JETTY_VERSION` : `10.0.x` (tier Java 11) ou `12.1.x`.
  - `SERVLET_PROFILE` : `jetty10-javax` | `jetty12-ee8` | `jetty12-ee11` (repli `jetty12-ee10`).
  - `JAVA_HOME` et `GDAL_VERSION` sont désormais **hérités de l'`ENV` de la base**
    (plus figés) → ils suivent automatiquement le variant Java 11 vs 21.
- **`startup.sh`** — choisit les modules de déploiement Jetty selon `SERVLET_PROFILE`
  (Jetty 10 : `deploy,jsp` sans préfixe `ee*` ; Jetty 12 : `ee8-*`, `ee10-*` ou `ee11-*`).
- **`migrate.sh`** — orchestrateur du staircase (voir plus bas).
- **`docker-compose.migration.yml`** — pour jouer **un** palier à la main.

## Spécificités de CE data dir (relevées à la validation)

- `updateSequence=1916` ; 151 coverages (rasters, dont ECW), 32 featuretypes, 2 wmslayers ; répertoire de sécurité en version 2.5.
- **Admin réel = `igeo`** (encodage `crypt1:`). ⚠️ Ne **jamais** passer
  `GEOSERVER_ADMIN_USER` / `GEOSERVER_ADMIN_PASSWORD` pendant la migration
  (sinon `update-credentials.sh` réécrit `users.xml` et écrase le compte).
- **Aucune extension** installée → `STABLE_EXTENSIONS` vide ; rien à réinstaller
  (WorldImage/ArcGRID) en 3.0. Le raster ECW passe par GDAL, pas par une extension.
- **3 stores WMS cascadés** + des noms de ressources avec espaces (`CRAIG - IGN - WMS`…).
  Les ruptures runtime associées (**URL Checks** en 2.24, **StrictHttpFirewall** en
  2.25) **n'empêchent pas le boot** ; elles ne concernent que le service en
  production et se traitent sur l'image finale 3.0.0.

## Procédure

### 0. Récupérer le data dir source

Source de prod : `viennagglo@195.42.149.140:/opt/data/geoserver/data-config`.

```bash
# Original intact (sauvegarde de reference)
mkdir -p /home/allfab/downloads/geoserver-2.16.4 \
&& scp -r viennagglo@195.42.149.140:/opt/data/geoserver/data-config \
        /home/allfab/downloads/geoserver-2.16.4/

# Copie source dans le projet (racine du data dir = migration/src/config)
cp -a /home/allfab/downloads/geoserver-2.16.4/data-config \
      ./migration/src/config

# Permissions user jetty (UID/GID 1000)
sudo chown -R 1000:1000 ./migration/src/config
```

### 1. Construire le variant de base Java 11

Depuis le dépôt `gdal-ecw-docker` :

```bash
docker build --build-arg JAVA_VERSION=11 -t allfab/gdal-ecw:java11 .
```

### 2. Lancer la migration complète

```bash
# construit chaque image de palier puis la joue (2.17.5 -> 3.0.0)
BUILD=1 ./migrate.sh

# ou, si les images de palier existent deja :
./migrate.sh

# reprise a un palier precis (1-based), sur la copie de travail existante :
START_STEP=8 ./migrate.sh
```

`migrate.sh` gère, pour chaque palier :
1. un **snapshot** de l'état d'entrée dans `migration/steps/<nn>-<gs>/config` (reprise possible) ;
2. le lancement du conteneur sur `migration/work/config` (data dir partagé, HTTPS off, port 8080) ;
3. l'attente d'un **HTTP 200** sur `/geoserver/web/`, puis une pause de flush ;
4. l'**arrêt gracieux** et le log docker dans `migration/logs/<nn>-<gs>.log` (avec compte des ERROR/WARN).

Variables utiles : `START_STEP`, `BUILD`, `FRESH`, `PORT`, `READY_TIMEOUT`,
`JETTY10`, `JETTY12`, `JAVA11_BASE`, `JAVA21_BASE`.

### 2 bis. Jouer un palier à la main (alternative)

```bash
cp -a migration/src/config migration/work/config      # une seule fois
GS_MIGRATE_IMAGE=allfab/geoserver-ecw:2.24.5 \
  docker compose -f docker-compose.migration.yml up
# attendre le statut "healthy", laisser flush, puis :
docker compose -f docker-compose.migration.yml down
```

## Arborescence de travail (`migration/`, git-ignoré)

```
migration/
├── src/config/        # data dir 2.16.4 d'origine (jamais modifie)
├── work/config/       # copie de travail, mutee palier par palier
├── steps/<nn>-<gs>/   # snapshot de l'etat d'ENTREE de chaque palier
└── logs/<nn>-<gs>.log # logs docker par palier
```

## Vérification finale (après 3.0.0)

1. Démarrer l'**image ECW complète 3.0.0** sur le data dir migré, en mode normal
   (HTTPS activé) ; se connecter à la console web avec le compte `igeo`.
2. Vérifier que **workspaces / stores / couches / styles** sont présents.
3. **Rendu ECW natif** : un `GetMap` WMS sur une couche raster ECW doit produire
   une image (valide GDAL/Hexagon sur le runtime final).
4. Réactiver/configurer ce qui ne concerne que la prod : **URL Checks** (WMS
   cascadés), **StrictHttpFirewall** (noms avec espaces), HTTPS/keystore.

## Points de vigilance par version

| Version | Rupture | Impact migration |
|---|---|---|
| 2.21 | Log4J 1.2 → Log4J 2 | logging réécrit, `.bak` créés — non bloquant |
| 2.24 | diskquota H2→HSQL ; **URL Checks** | non bloquant au boot ; WMS cascadés à autoriser en prod |
| 2.25 | **StrictHttpFirewall** ; auto-escape FreeMarker | non bloquant au boot ; noms à espaces à surveiller en prod |
| 2.26 | NetCDF 5 / GRIB ; entity resolution | sans objet ici (pas de GRIB) |
| 2.27 | CSP par défaut ; loader optimisé | `GEOSERVER_DATA_DIR_LOADER_ENABLED=false` si souci |
| 2.28 | **JAI-Ext → ImageN** (Java 17 min) | bascule tier Java 21 |
| 3.0 | **Jakarta EE / Servlet 6.1** | bascule modules `ee11-*` (Jetty 12.1) |

## Repli connu

Si un palier ancien ne démarre pas sur **Java 11 + Jetty 10** (support Java 11
encore jeune en 2.16/2.17), rabattre ce tier sur **Jetty 9.4** : ajouter un profil
`jetty9-javax` dans `startup.sh` et ajuster `JETTY10` dans `migrate.sh`. Le
paramétrage rend ce changement local.
