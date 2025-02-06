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

## Supported tags and respective Dockerfile links
- [`2.25.3-debian12.7`](http://github.com)

## How to build ?
```bash
docker build ...
```

# How to quickstart ?

## Docker compose
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

## VOLUMES
```bash
mkdir -pv ./geoserver/{config,data,logs,gwc} \
&& mkdir -pv ./geoserver/data/{raster,vector} \
&& mkdir -pv ./geoserver/gwc/{config,cache} \
&& chown -Rf 1000:1000 ./geoserver
```

Environments variables :

- `GEOSERVER_HOME`=/app/geoserver
- `GEOSERVER_DATA_DIR`=/app/geoserver/config
- `GEOSERVER_GEODATA_DIR`=/app/geoserver/data
- `GEOSERVER-_LOG_DIR`=/app/geoserver/logs
- `GEOSERVER_LOG_LOCATION`=/app/geoserver/logs/geoserver.log
- `GEOWEBCACHE_CONFIG_DIR`=/app/geoserver/gwc/config
- `GEOWEBCACHE_CACHE_DIR`=/app/geoserver/gwc/cache


Check [http://localhost:8080/geoserver/⁠](http://localhost:8080/geoserver/) to see the geoserver application page and login with geoserver defaults credentials :

> `admin:geoserver`

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