# Geoserver image with ECW and JP2ECW support running on Debian Bookworm official image

<div align="center">

[![status-badge](https://forgejo.ci.allfabox.fr/api/badges/2/status.svg)](https://forgejo.ci.allfabox.fr/repos/2)
[![Docker Pulls](https://img.shields.io/docker/pulls/allfab/geoserver-ecw)](https://hub.docker.com/r/allfab/geoserver-ecw)


[![Geoserver](https://geoserver.org/img/geoserver-logo.png)](https://geoserver.org/)
</div>

- Debian based Linux
- OpenJDK12
- Jetty 12
- GDAL 3.9.2
- Geoserver :
   - Native Java advanced imaging (JAI) is installed
   - JAI-EXT⁠ is enabled by default
   - ERDAS ECW and JP2ECW (JPG2000) renderer

> IMPORTANT NOTE: Please change the default geoserver admin password ! The default masterpw is located in this file (within the docker container): /app/geoserver/config/security/masterpw/default/masterpw

## Supported tags and respective `Dockerfile` links
 - [`3.10.1` - `3.10.1-12.9-slim` - `latest`⁠](https://forgejo.allfabox.fr/allfab/gdal-ecw-3.10.1-12.9-slimdocker/src/branch/main/Dockerfile)

 ---

| Tag                  | Description
| -------------------- | ----------------------------------------------------------------------------------- |
| `latest`             | [Latest release version](https://forgejo.allfabox.fr/allfab/gdal-ecw-docker)                                                            |
| `3.10.1`, `3.10.1-12.9-slim` | [GDAL/OGR 3.10.1 Release Notes](https://github.com/OSGeo/gdal/blob/v3.10.1/NEWS.md) |

## What is Geoserver ?


## How to build ?
```bash
docker build -f ./Dockerfile --no-cache=true --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') -t allfab/geoserver-ecw:latest -t allfab/geoserver-ecw:2.26.2 -t allfab/geoserver-ecw:2.26.2-12.9-slim .
```

## How to quickstart ?

### Volumes
In order to manage the correct permissions on the directories mounted as a volume on the `geoserver` container, you must first create the structure of the folders that will host the Geoserver data.<br />
*Afin de gérer les bonnes permissions sur les répertoires montés en volume sur le container `geoserver`, il faut au préalable créer la structure des dossiers qui vont accueillir les données de Geoserver*
```bash
mkdir -pv ./geoserver/{config,data,logs,gwc} \
&& mkdir -pv ./geoserver/data/{raster,vector} \
&& mkdir -pv ./geoserver/gwc/{config,cache} \
&& chown -Rf 1000:1000 ./geoserver
```

```bash
tree -L 2 geoserver
geoserver
├── config
├── data
│   ├── raster
│   └── vector
├── gwc
│   ├── cache
│   └── config
└── logs

9 directories, 0 files
```

### Docker run
```bash
docker run -it --name geoserver \
    -v ./geoserver/config:/app/geoserver/config \
    -v ./geoserver/data/raster:/app/geoserver/data/raster \
    -v ./geoserver/data/vector:/app/geoserver/data/vector \
    -v ./geoserver/logs:/app/geoserver/logs \
    -v ./geoserver/gwc/config:/app/geoserver/gwc/config \
    -v ./geoserver/gwc/cache:/app/geoserver/gwc/cache \
    -p 8080:8080 -d allfab/geoserver-ecw:latest
```
### Docker compose
```yml
---
services:
  geoserver:
    container_name: geoserver
    image: allfab/geoserver-ecw:latest
    restart: unless-stopped
    ports:
      - 8080:8080
    volumes:
      - ./geoserver/config:/app/geoserver/config
      - ./geoserver/data/raster:/app/geoserver/data/raster
      - ./geoserver/data/vector:/app/geoserver/data/vector
      - ./geoserver/logs:/app/geoserver/logs
      - ./geoserver/gwc/config:/app/geoserver/gwc/config
      - ./geoserver/gwc/cache:/app/geoserver/gwc/cache
    networks:
      - geoserver

networks:
  geoserver:
    name: geoserver
    driver: bridge
```

## Users

The main user of this container is named `jetty` and its default directory is `/srv/jetty/geoserver-base`. It is part of the `sudo` group and therefore benefits from privilege escalation thanks to the configuration of the `/etc/sudoers` file.<br />
*L'utilisateur principal de ce container se nomme `jetty` et son répertoire par défaut est `/srv/jetty/geoserver-base`. Il fait parti du groupe `sudo` et bénéficie donc d'une escalation de privilège graĉe à la configuration du fichier `/etc/sudoers`.*


## Environments variables

- `GEOSERVER_HOME`=/app/geoserver
- `GEOSERVER_DATA_DIR`=/app/geoserver/config
- `GEOSERVER_GEODATA_DIR`=/app/geoserver/data
- `GEOSERVER_LOG_DIR`=/app/geoserver/logs
- `GEOSERVER_LOG_LOCATION`=/app/geoserver/logs/geoserver.log
- `GEOWEBCACHE_CONFIG_DIR`=/app/geoserver/gwc/config
- `GEOWEBCACHE_CACHE_DIR`=/app/geoserver/gwc/cache

> IMPORTANT NOTE: Not yet implemented in the environment variables of the docker-compose file.<br />*Pas encore implémenté au niveau des variables d'environnments du fichier docker-compose.*

## Docker run
```bash
docker run -it --name geoserver \
    -v ./geoserver/config:/app/geoserver/config \
    -v ./geoserver/data/raster:/app/geoserver/data/raster \
    -v ./geoserver/data/vector:/app/geoserver/data/vector \
    -v ./geoserver/logs:/app/geoserver/logs \
    -v ./geoserver/gwc/config:/app/geoserver/gwc/config \
    -v ./geoserver/gwc/cache:/app/geoserver/gwc/cache \
    -p 8080:8080 -d allfab/geoserver-ecw:latest
```

Check [http://localhost:8080/geoserver/⁠](http://localhost:8080/geoserver/) to see the geoserver application page and login with geoserver defaults credentials :

> `admin:geoserver`