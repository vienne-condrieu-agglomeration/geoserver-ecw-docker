# Geoserver image with ECW and JP2ECW support running on Debian Bookworm official image

<div align="center">

[![status-badge](https://forgejo.ci.allfabox.fr/api/badges/2/status.svg)](https://forgejo.ci.allfabox.fr/repos/2)
[![Docker Pulls](https://img.shields.io/docker/pulls/allfab/geoserver-ecw)](https://hub.docker.com/r/allfab/geoserver-ecw)


[![Geoserver](https://geoserver.org/img/geoserver-logo.png)](https://geoserver.org/)
</div>

- Debian based Linux
- OpenJDK12
- Jetty 12
- GDAL 3.10.1
- Geoserver :
   - Native Java advanced imaging (JAI) is installed
   - JAI-EXT⁠ is enabled by default
   - ERDAS ECW and JP2ECW (JPG2000) renderer

> IMPORTANT NOTE: Please change the default geoserver admin password ! The default masterpw is located in this file (within the docker container): /app/geoserver/config/security/masterpw/default/masterpw

## Supported tags and respective `Dockerfile` links
 - [`2.26.2` - `2.26.2-12.9-slim` - `latest`⁠](https://forgejo.allfabox.fr/allfab/geoserver-ecw-docker/src/branch/main/Dockerfile)

 ---

| Tag                  | Description
| -------------------- | ----------------------------------------------------------------------------------- |
| `latest`             | [Latest release version](https://forgejo.allfabox.fr/allfab/geoserver-ecw-docker/)                                                            |
| `2.26.2`, `2.26.2-12.9-slim` | [Geoserver 2.26.2 Release Notes](https://github.com/geoserver/geoserver/releases/tag/2.26.2) |

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
&& mkdir -pv ./geoserver/jks \
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
├── jks
│   └── keystore
└── logs

10 directories, 1 files
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
    -e GEOSERVER_CSRF_WHITELIST=example.org
    -p 8080:8080 -d allfab/geoserver-ecw:latest
```

Check [http://localhost:8080/geoserver/⁠](http://localhost:8080/geoserver/) to see the geoserver application page and login with geoserver defaults credentials :

> `admin:geoserver`


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
    environment:
      - GEOSERVER_CSRF_WHITELIST=example.org
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

### Volumes

- `GEOSERVER_HOME`=/app/geoserver
- `GEOSERVER_DATA_DIR`=/app/geoserver/config
- `GEOSERVER_GEODATA_DIR`=/app/geoserver/data
- `GEOSERVER_LOG_DIR`=/app/geoserver/logs
- `GEOSERVER_LOG_LOCATION`=/app/geoserver/logs/geoserver.log
- `GEOWEBCACHE_CONFIG_DIR`=/app/geoserver/gwc/config
- `GEOWEBCACHE_CACHE_DIR`=/app/geoserver/gwc/cache

> IMPORTANT NOTE: Not yet implemented in the environment variables of the docker-compose file.<br />*Pas encore implémenté au niveau des variables d'environnements du fichier docker-compose.*

### Default user

- `GEOSERVER_ADMIN_USER`=Admin_username 	
- `GEOSERVER_ADMIN_PASSWORD`=Admin_password

> IMPORTANT NOTE: After the initial setup, it's recommended to remove the GEOSERVER_ADMIN_USER and GEOSERVER_ADMIN_PASSWORD variable. Otherwise, newly added roles and users may be overwritten by the next time the container is restarted.<br />*Après la configuration initiale, il est recommandé de supprimer les variables GEOSERVER_ADMIN_USER et GEOSERVER_ADMIN_PASSWORD. Dans le cas contraire, les rôles et utilisateurs nouvellement ajoutés risquent d'être écrasés au prochain redémarrage du conteneur.*

### CSRF Protection

The GeoServer web admin employs a CSRF (Cross-Site Request Forgery) protection filter that will block any form submissions that didn’t appear to originate from GeoServer. This can sometimes cause problems for certain proxy configurations.

To allow-list your proxy with the CSRF filter, you can use the GEOSERVER_CSRF_WHITELIST property. This property is a comma-separated list of domains, of the form <domainname>.<TLD>, and can contain a subdomains. Alternatively, you can disable the CSRF filter by setting the GEOSERVER_CSRF_DISABLED property to true.

- `GEOSERVER_CSRF_WHITELIST`=`example.org`
- `GEOSERVER_CSRF_DISABLED`=`false`

### EXTENSIONS

- `INSTALL_EXTENSIONS`=`true`
- `STABLE_EXTENSIONS`=`"wps,ysld,dxf"`
