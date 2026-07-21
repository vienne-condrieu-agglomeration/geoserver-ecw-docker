# GEOSERVER-ECW Build

```bash
docker build --no-cache=true --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') -t allfab/geoserver-ecw:latest .

docker build -f ./Dockerfile --no-cache=true --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') -t allfab/geoserver-ecw:latest -t allfab/geoserver-ecw:2.26.2 -t allfab/geoserver-ecw:2.26.2-12.9-slim .

docker build --build-arg BUILD_DATE=20250210 -t allfab/geoserver-ecw:latest .
```

# Docker run

## Docker Compose File

```bash
docker run -it --name geoserver \
    -v ./geoserver/config:/app/geoserver/config \
    -v ./geoserver/data/raster:/app/geoserver/data/raster \
    -v ./geoserver/data/vector:/app/geoserver/data/vector \
    -v ./geoserver/logs:/app/geoserver/logs \
    -v ./geoserver/gwc/config:/app/geoserver/gwc/config \
    -v ./geoserver/gwc/cache:/app/geoserver/gwc/cache \
    -p 8080:8080 -p 8543:8543 -d allfab/geoserver-ecw:latest
```

## Docker Run

### Without HTTPS

```bash
docker run -it --name geoserver \
    -e HTTPS_ENABLED=false \
    -p 8080:8080 -d allfab/geoserver-ecw:latest
```

### With HTTPS

```bash
docker run -it --name geoserver \
    -e HTTPS_ENABLED=true \
    -e HTTPS_KEYSTORE_FILE=etc/keystore \
    -e HTTPS_KEYSTORE_PASSWORD=mypassword \
    -v ./geoserver/jks/keystore:/srv/jetty/geoserver-base/etc/keystore \
    -p 8080:8080 -p 8443:8443 -d allfab/geoserver-ecw:latest
```

### With UPDATE DEFAULT ADMIN USER CREDENTIALS

```bash
docker run -it --name geoserver \
    -e HTTPS_ENABLED=true \
    -e HTTPS_KEYSTORE_FILE=etc/keystore \
    -e HTTPS_KEYSTORE_PASSWORD=mypassword \
    -e GEOSERVER_ADMIN_USER=admindemo \
    -e GEOSERVER_ADMIN_PASSWORD=demodemo \
    -v ./geoserver/jks/keystore:/srv/jetty/geoserver-base/etc/keystore \
    -p 8080:8080 -p 8443:8443 -d allfab/geoserver-ecw:latest
```

### With ADDITIONAL EXTENSIONS

```bash
docker run -it --name geoserver \
    -e HTTPS_ENABLED=true \
    -e HTTPS_KEYSTORE_FILE=etc/keystore \
    -e HTTPS_KEYSTORE_PASSWORD=mypassword \
    -e GEOSERVER_ADMIN_USER=admindemo \
    -e GEOSERVER_ADMIN_PASSWORD=demodemo \
    -e INSTALL_EXTENSIONS=true \
    -e STABLE_EXTENSIONS=wps,ysld,dxf
    -v ./geoserver/jks/keystore:/srv/jetty/geoserver-base/etc/keystore \
    -v ./geoserver/additional_extensions:/app/geoserver/additional_extensions \
    -p 8080:8080 -p 8443:8443 -d allfab/geoserver-ecw:latest
```

# Execute container

```bash
docker exec -it geoserver /bin/bash
```

# Delete All allfab/geoserver-ecw images

```bash
docker rmi --force $(docker images -q allfab/geoserver-ecw)
```

# Migration progressive d'un data dir (2.16 → 3.0)

Voir `migrate.sh` et la section « Migration multi-versions » de `CLAUDE.md`.

## 1. Variant de base Java 11 (pour les paliers 2.16 → 2.27)

Depuis le dépôt `gdal-ecw-docker` :

```bash
docker build --build-arg JAVA_VERSION=11 -t allfab/gdal-ecw:java11 .
```

## 2. Construire une image d'un palier donné

```bash
# Exemple palier 2.17.5 (tier Java 11 / Jetty 10 / javax)
docker build -f ./Dockerfile \
  --build-arg BASE_IMAGE=allfab/gdal-ecw:java11 \
  --build-arg GS_VERSION=2.17.5 \
  --build-arg JETTY_VERSION=10.0.24 \
  --build-arg SERVLET_PROFILE=jetty10-javax \
  --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
  -t allfab/geoserver-ecw:2.17.5 .

# Exemple palier final 3.0.0 (tier Java 21 / Jetty 12.1 / Jakarta)
docker build -f ./Dockerfile \
  --build-arg BASE_IMAGE=allfab/gdal-ecw:latest \
  --build-arg GS_VERSION=3.0.0 \
  --build-arg JETTY_VERSION=12.1.7 \
  --build-arg SERVLET_PROFILE=jetty12-ee11 \
  --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
  -t allfab/geoserver-ecw:3.0.0 .
```

> 3.0 utilise `jetty12-ee11` (Jakarta Servlet 6.1 / EE11). Repli `jetty12-ee10` si le WAR s'avère en Servlet 6.0.

## 3. Lancer la migration

Placer le data dir 2.16.4 dans `migration/src/config`, puis :

```bash
BUILD=1 ./migrate.sh            # construit + joue chaque palier 2.17.5 → 3.0.0
# ou, si les images existent deja :
./migrate.sh
# reprise a un palier precis (1-based) :
START_STEP=8 ./migrate.sh
```
