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

## Matrice Java consolidée (pourquoi Java 11 pour tout le tier ancien)

Le choix « Java 11 pour 2.17 → 2.27 » n'est pas arbitraire : **Java 11 est le seul
dénominateur commun** qui boote toute la plage. Vérifié sur la doc GeoServer
officielle (juillet 2026) :

| GeoServer | Java 8 | Java 11 | Java 17 | Java 21 |
|---|:---:|:---:|:---:|:---:|
| 2.16 → 2.21 | ✅ | ✅ | — | — |
| 2.22 → 2.24 | ✅/— | ✅ | ✅ | — |
| 2.25 | — | ✅ | ✅ | — |
| 2.26 → **2.27** | — | ✅ | ✅ | ✅ |
| 2.28+ / 3.0 | — | ❌ | ✅ (min) | ✅ |

- **Java 8** ne monte pas jusqu'à 2.25+ (qui exige 11 minimum).
- **Java 17** ne descend pas jusqu'à 2.16 (qui ne supporte que 8/11).
- **2.27 est la dernière version compatible Java 11** ; c'est **2.28** (tier Java 21)
  qui impose Java 17 minimum. La bascule de tier tombe donc pile entre l'étape 11
  (2.27.5, Java 11) et l'étape 12 (2.28.4, Java 21) — cohérent avec la matrice des
  paliers ci-dessous.

> Sources : [Download GeoServer (matrice Java par version)](https://geoserver.org/download/),
> [Upgrade to Java 17 (wiki GeoServer)](https://github.com/geoserver/geoserver/wiki/Upgrade-to-Java-17).

### Contrainte de build du variant Java 11 (Debian Trixie)

L'image de base `allfab/gdal-ecw` repose sur **Debian 13 (Trixie)**, qui **ne
package plus openjdk-11** (la série OpenJDK Debian est passée à `17` en Bookworm,
`21`/`25` en Trixie). Un `docker build --build-arg JAVA_VERSION=11` échouait donc
sur `Package 'openjdk-11-jre-headless' has no installation candidate`.

**Correctif appliqué dans `gdal-ecw-docker/Dockerfile`** : quand `JAVA_VERSION=11`,
on installe **Eclipse Temurin 11 (Adoptium)** au lieu de l'OpenJDK Debian, dans le
builder (`temurin-11-jdk`) **et** le runner (`temurin-11-jre`). La suite du dépôt
Adoptium suit le nom de code de la base (`$VERSION_CODENAME`, donc `trixie` — canal
publié par Adoptium) ; le paquet Temurin embarque son propre JDK, la suite ne sert
qu'aux métadonnées apt. Un **symlink stable
`/usr/lib/jvm/gdal-java`** (exposé via `JAVA_HOME`) découple `JAVA_HOME` et
`LD_LIBRARY_PATH` du fournisseur, si bien que `21`/`25` continuent d'utiliser
l'OpenJDK Debian sans changement. Alternatives écartées : base Bullseye (Debian 11
en fin de vie + tous les suffixes de libs `t64` de Trixie à réécrire).

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
- **Chemins des coverageStores en ABSOLU de prod** : chaque `coveragestore.xml`
  référence `file:///opt/data/geoserver/data-src/raster/…` (et **non** la
  convention `/app/geoserver/data/raster` du `docker-compose.yml` racine). Pour la
  validation du rendu, on monte donc les données à **ce chemin absolu exact**
  plutôt que de réécrire ~130 `coveragestore.xml`. Stores raster : **12 ECW**
  (orthos `ortho/scot_*` de 2,6 à 6,3 Go), **~180 JP2ECW** (surtout `urbanisme/`),
  le reste en GeoTIFF / ImageMosaic.
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
      ./migration/src

# On renomme le dossier
mv ./migration/src/data-config ./migration/src/config

# Permissions user jetty (UID/GID 1000)
sudo chown -R 1000:1000 ./migration/src/config
```

> Le staircase ne migre que le **data dir** (config). Les **données raster**
> elles-mêmes (ECW, JP2ECW, GeoTIFF…) ne sont **pas** nécessaires pour le boot ;
> elles ne servent qu'à la validation finale du rendu (voir plus bas) et sont
> rapatriées séparément depuis `…:/opt/data/geoserver/data-src` (≈ 41 Go).

### 1. Construire le variant de base Java 11

Depuis le dépôt `gdal-ecw-docker` :

```bash
docker build --build-arg JAVA_VERSION=11 -t allfab/gdal-ecw:java11 .
```

> Sur Debian Trixie, `JAVA_VERSION=11` installe **Temurin 11 (Adoptium)** et non
> l'OpenJDK Debian (absent des dépôts) — cf. *Contrainte de build du variant
> Java 11* plus haut. Le build nécessite donc un accès réseau à
> `packages.adoptium.net`.

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
├── src/data/          # donnees raster de prod rapatriees (ECW/JP2ECW/TIFF, ~41 Go, RO a la validation)
├── work/config/       # copie de travail, mutee palier par palier (= data dir migre final)
├── work/logs/         # logs GeoServer du conteneur de validation 3.0.0
├── work/gwc/          # config + cache GeoWebCache de la validation
├── out/               # PNG des GetMap de validation (ECW, JP2ECW)
├── steps/<nn>-<gs>/   # snapshot de l'etat d'ENTREE de chaque palier
├── logs/<nn>-<gs>.log # logs docker par palier
└── docker-compose-3.0.0.yml   # compose de validation bout-en-bout (rendu ECW)
```

## Validation finale de bout en bout (faite le 2026-07-22)

La validation du staircase (13/13 paliers, 0 ERROR) ne portait que sur le **boot**.
Cette étape confirme le **rendu ECW natif réel** sur l'image finale, avec les
vraies données de prod.

### Compose de validation dédié

`migration/docker-compose-3.0.0.yml` monte le data dir migré + les rasters (en
lecture seule) au chemin absolu attendu par les stores, **sans** identifiants
admin (le compte `igeo` du data dir est préservé) :

```yaml
services:
  geoserver-migration:
    image: allfab/geoserver-ecw:3.0.0
    ports: ["8080:8080"]
    volumes:
      - ./work/config:/app/geoserver/config              # data dir migré → GEOSERVER_DATA_DIR
      - ./src/data:/opt/data/geoserver/data-src:ro        # rasters au chemin ABSOLU de prod (RO)
      - ./work/logs:/app/geoserver/logs
      - ./work/gwc/config:/app/geoserver/gwc/config
      - ./work/gwc/cache:/app/geoserver/gwc/cache
    environment:
      - HTTPS_ENABLED=false
      - INSTALL_EXTENSIONS=false
      - GEOSERVER_CSRF_DISABLED=true
      # PAS de GEOSERVER_ADMIN_USER / GEOSERVER_ADMIN_PASSWORD (admin réel = igeo)
```

```bash
cd migration
docker compose -f docker-compose-3.0.0.yml up -d
docker compose -f docker-compose-3.0.0.yml logs -f
```

> Les répertoires d'écriture (`work/logs`, `work/gwc/{config,cache}`) doivent
> exister et appartenir à **1000:1000** avant le lancement.

### Résultats obtenus

| Contrôle | Résultat |
|---|---|
| Boot | **EE11** (`oeje11w`) / Jetty **12.1.7** / JVM **21**, **GDAL 3.13.1 natif chargé** |
| WMS `GetCapabilities` | **155 couches / 15 workspaces** annoncées |
| **GetMap ECW** — `ortho:vca_scot_ortho_2023` (5,8 Go) | PNG 800×482 RGB, écart-type ≈ 64/canal → **rendu Hexagon réel**, pas de tuile vide ✅ |
| **GetMap JP2ECW** — `urbanisme-pprni:38107_PLU_PPRNI_ALEAS_20190515` | PNG 700×495 RGB, 37 909 couleurs distinctes ✅ |
| Console web (`/geoserver/web/`) | 302 CryptoMapper Wicket → page login **200** (formulaire username/password) ✅ |
| REST (`/rest/workspaces`) | **401** — sécurité active, admin `igeo` préservé ✅ |
| Logs | **0 erreur** ECW / GDAL / Hexagon |

Exemple de requête GetMap ECW validée (WMS 1.1.1, EPSG:2154, bbox native) :

```
http://localhost:8080/geoserver/ortho/wms?service=WMS&version=1.1.1&request=GetMap
  &layers=ortho:vca_scot_ortho_2023&styles=&srs=EPSG:2154
  &bbox=828188.37844,6482573.63106,863634.72844,6503932.43106
  &width=800&height=482&format=image/png
```

Les PNG produits sont archivés dans `migration/out/`.

> **Note** : le contrôle REST authentifié (énumération `igeo`) n'a pas été joué
> faute de mot de passe sous la main ; la présence des workspaces/couches a été
> vérifiée via WMS `GetCapabilities`, qui couvre le besoin.

#### Piège du Proxy Base URL en accès direct `localhost`

Le data dir de prod fige un **Proxy Base URL** sur le domaine public dans
`global.xml` :

```xml
<proxyBaseUrl>https://geo-ressources.vienne-condrieu-agglomeration.fr/geoserver</proxyBaseUrl>
<useHeadersProxyURL>true</useHeadersProxyURL>
```

GeoServer construit **toutes** ses URL absolues (dont l'`action` du formulaire de
login) à partir de ce champ. En accès direct `http://localhost:8080` (sans reverse
proxy émettant les en-têtes `X-Forwarded-*`), l'`action` pointe vers le domaine de
prod ; la **CSP `form-action 'self'`** (activée par défaut depuis 2.27) bloque
alors la connexion :

```
Content-Security-Policy … (form-action) … j_spring_security_check … enfreint « form-action 'self' »
```

**Correctif pour la validation locale uniquement** — neutraliser le proxy pour que
GeoServer dérive l'URL de la requête, puis redémarrer le conteneur :

```xml
<proxyBaseUrl></proxyBaseUrl>
<useHeadersProxyURL>false</useHeadersProxyURL>
```

L'`action` devient `http://localhost:8080/geoserver/j_spring_security_check`
(= `'self'`), la CSP passe, connexion `igeo` OK. **En prod, ce réglage n'est pas
nécessaire** : le reverse proxy envoie les `X-Forwarded-*` et l'origine réelle
correspond au `proxyBaseUrl`, donc la CSP est satisfaite — d'où le rappel de
restauration ci-dessous.

### Reste à faire pour la mise en production

Ces points ne concernent que le **service en prod**, pas la migration du data dir :

1. Réactiver **HTTPS/keystore** (mode `docker-compose.yml` racine).
2. Configurer les **URL Checks** (WMS cascadés) et le **StrictHttpFirewall**
   (ressources aux noms avec espaces).
3. Se connecter à la console avec `igeo` pour un contrôle visuel final.
4. **Restaurer le Proxy Base URL** dans `global.xml` s'il a été neutralisé pour la
   validation locale (cf. *Piège du Proxy Base URL* ci-dessus) :
   ```xml
   <proxyBaseUrl>https://geo-ressources.vienne-condrieu-agglomeration.fr/geoserver</proxyBaseUrl>
   <useHeadersProxyURL>true</useHeadersProxyURL>
   ```

## Points de vigilance par version

| Version | Rupture | Impact migration |
|---|---|---|
| 2.21 | Log4J 1.2 → Log4J 2 ; **CryptoMapper Wicket** activé | logging réécrit, `.bak` créés — non bloquant. `/geoserver/web/` répond désormais **302** vers une URL chiffrée (`?wicket-crypt=…`) puis 200 : la sonde de `migrate.sh` suit la redirection (`curl -L`) — sinon faux négatif au boot |
| 2.24 | diskquota H2→HSQL ; **URL Checks** ; **JSESSIONID `HttpOnly` requis** par le CryptoMapper | non bloquant au boot ; WMS cascadés à autoriser en prod. La sonde doit **renvoyer le cookie** (`curl -L -b /dev/null`), sinon la redirection Wicket reboucle (302 ×50) → faux négatif |
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
