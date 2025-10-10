# Geoserver image with ECW and JP2ECW support running on Debian Bookworm official image

<div align="center">

[![status-badge](https://forgejo.ci.allfabox.fr/api/badges/2/status.svg)](https://forgejo.ci.allfabox.fr/repos/2)
[![Docker Pulls](https://img.shields.io/docker/pulls/allfab/geoserver-ecw)](https://hub.docker.com/r/allfab/geoserver-ecw)

[![Geoserver](https://geoserver.org/img/geoserver-logo.png)](https://geoserver.org/)

</div>

- Debian based Linux `13.1`
- OpenJDK `21`
- Jetty `12.1.1`
- GDAL `3.11.4`
- Geoserver `2.27.2` :
  - Native Java advanced imaging (JAI) is installed
  - JAI-EXT⁠ is enabled by default
  - ERDAS ECW and JP2ECW (JPG2000) renderer

> IMPORTANT NOTE: Please change the default geoserver admin password ! The default masterpw is located in this file (within the docker container): /app/geoserver/config/security/masterpw/default/masterpw

## Supported tags and respective `Dockerfile` links

- [`2.27.2` - `2.27.2-13.1-slim` - `latest`⁠](https://forgejo.allfabox.fr/allfab/geoserver-ecw-docker/src/branch/main/Dockerfile)
- [`2.27.1` - `2.27.1-12.11-slim`⁠](https://forgejo.allfabox.fr/allfab/geoserver-ecw-docker/src/branch/main/Dockerfile)

---

| Tag                                    | Description                                                                                  |
| -------------------------------------- | -------------------------------------------------------------------------------------------- |
| `latest`                               | [Latest release version](https://forgejo.allfabox.fr/allfab/geoserver-ecw-docker/)           |
| `2.27.2`, `2.27.2-13.1-slim`, `latest` | [Geoserver 2.27.2 Release Notes](https://github.com/geoserver/geoserver/releases/tag/2.27.2) |
| `2.27.1`, `2.27.1-12.11-slim`          | [Geoserver 2.27.1 Release Notes](https://github.com/geoserver/geoserver/releases/tag/2.27.1) |

## What is Geoserver ?

## How to build ?

```bash
docker build -f ./Dockerfile --no-cache=true --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') -t allfab/geoserver-ecw:latest -t allfab/geoserver-ecw:2.27.2 -t allfab/geoserver-ecw:2.27.2-13.1-slim .
```

## How to quickstart ?

### Volumes

In order to manage the correct permissions on the directories mounted as a volume on the `geoserver` container, you must first create the structure of the folders that will host the Geoserver data.<br />
_Afin de gérer les bonnes permissions sur les répertoires montés en volume sur le container `geoserver`, il faut au préalable créer la structure des dossiers qui vont accueillir les données de Geoserver_

```bash
mkdir -pv ./geoserver/{config,data,logs,gwc} \
&& mkdir -pv ./geoserver/data/{raster,vector} \
&& mkdir -pv ./geoserver/gwc/{config,cache} \
&& mkdir -pv ./geoserver/jks \
&& mkdir -pc ./geoserver/additional_extensions \
&& chown -Rf 1000:1000 ./geoserver
```

```bash
tree -L 2 geoserver
geoserver
├── additional_extensions
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

11 directories, 1 files
```

> IMPORTANT NOTE: Remember to put the keystore associated with your SSL certificate in the `jks` folder.<br />_Pensez à mettre dans le dossier `jks` le keystore associé à votre certificat SSL._

```bash
#!/bin/bash
# keystore-generator.sh

keytool -genkey \
    -alias geoserver_localhost \
    -keystore ./keystore \
    -deststoretype pkcs12 \
    -storepass mypassword \
    -keypass mypassword \
    -keyalg RSA \
    -keysize 2048 \
    -dname "CN=geoserver.mydomain.com, OU=geoserver.mydomain.com, O=Unknown, L=Unknown, ST=Unknown, C=FR"

# ON RHEL BASE
printf 'mypassword\nchangeit\n' | keytool -importkeystore \
    -srckeystore /etc/pki/java/cacerts \
    -destkeystore ./keystore \
    -deststoretype pkcs12

# ON DEBIAN/UBUNTU BASE
printf 'mypassword\nchangeit\n' | keytool -importkeystore \
    -srckeystore /etc/ssl/certs/java/cacerts \
    -destkeystore ./keystore \
    -deststoretype pkcs12

printf 'mypassword\nyes\n' | keytool -import -alias cert_ssl -file ./my_certificate.crt -keystore ./keystore
```

### Docker run

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
    -e HTTPS_KEYSTORE_PASSWORD=password \
    -v ./geoserver/jks/keystore:/srv/jetty/geoserver-base/etc/keystore \
    -p 8080:8080 -p 8443:8443 -d allfab/geoserver-ecw:latest
```

### With UPDATE DEFAULT ADMIN USER CREDENTIALS

```bash
docker run -it --name geoserver \
    -e HTTPS_ENABLED=true \
    -e HTTPS_KEYSTORE_FILE=etc/keystore \
    -e HTTPS_KEYSTORE_PASSWORD=password \
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
    -e HTTPS_KEYSTORE_PASSWORD=password \
    -e GEOSERVER_ADMIN_USER=admindemo \
    -e GEOSERVER_ADMIN_PASSWORD=demodemo \
    -e INSTALL_EXTENSIONS=true \
    -e STABLE_EXTENSIONS=wps,ysld,dxf
    -v ./geoserver/jks/keystore:/srv/jetty/geoserver-base/etc/keystore \
    -v ./geoserver/additional_extensions:/app/geoserver/additional_extensions \
    -p 8080:8080 -p 8443:8443 -d allfab/geoserver-ecw:latest
```

Check [http://localhost:8080/geoserver/⁠](http://localhost:8080/geoserver/) to see the geoserver application page and login with geoserver defaults credentials :

> `admin:geoserver`

### Docker compose

```bash
tree -La 3 ../geoserver-stack
.
├── docker-compose.yml
├── .env
└── geoserver
    ├── additional_extensions
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

11 directories, 3 files
```

```yml
---
# docker-compose-yml
services:
  geoserver:
    container_name: geoserver
    image: allfab/geoserver-ecw:latest
    restart: unless-stopped
    ports:
      - 8080:8080
      - 8443:8443
    volumes:
      - ./geoserver/config:/app/geoserver/config
      - ./geoserver/data/raster:/app/geoserver/data/raster
      - ./geoserver/data/vector:/app/geoserver/data/vector
      - ./geoserver/logs:/app/geoserver/logs
      - ./geoserver/gwc/config:/app/geoserver/gwc/config
      - ./geoserver/gwc/cache:/app/geoserver/gwc/cache
      - ./geoserver/jks/keystore:/srv/jetty/geoserver-base/etc/keystore # Needed if HTTPS_ENABLED=true, keystore file mounted on container
      - ./geoserver/additional_extensions:/app/geoserver/additional_extensions # Needed if INSTALL_EXTENSIONS=true
    environment:
      - GEOSERVER_CSRF_WHITELIST=example.org,*.example.org
      - HTTPS_ENABLED=true # REQUIRE : true | false
      - HTTPS_KEYSTORE_FILE=etc/keystore # Needed if HTTPS_ENABLED=true, keystore file mounted on container
      - HTTPS_KEYSTORE_PASSWORD=${HTTPS_KEYSTORE_PASSWORD} # Needed if HTTPS_ENABLED=true and HTTPS_KEYSTORE_FILE=etc/keystore
      - GEOSERVER_ADMIN_USER=${GEOSERVER_ADMIN_USER} # Optional else admin
      - GEOSERVER_ADMIN_PASSWORD=${GEOSERVER_ADMIN_PASSWORD} # Optional else geoserver
      - INSTALL_EXTENSIONS=true # Optional : true | false
      - STABLE_EXTENSIONS=wps,ysld,dxf # Needed if INSTALL_EXTENSIONS=true
    networks:
      - geoserver

networks:
  geoserver:
    name: geoserver
    driver: bridge
```

```
# .env
COMPOSE_PROJECT_NAME=geoserver

# GEOSERVER
GEOSERVER_ADMIN_USER="myuser"
GEOSERVER_ADMIN_PASSWORD="mypassword"
```

## Users

The main user of this container is named `jetty` and its default directory is `/srv/jetty/geoserver-base`. It is part of the `sudo` group and therefore benefits from privilege escalation thanks to the configuration of the `/etc/sudoers` file.<br />
_L'utilisateur principal de ce container se nomme `jetty` et son répertoire par défaut est `/srv/jetty/geoserver-base`. Il fait parti du groupe `sudo` et bénéficie donc d'une escalation de privilège graĉe à la configuration du fichier `/etc/sudoers`._

## Environments variables

### Volumes

- `GEOSERVER_HOME`=/app/geoserver
- `GEOSERVER_DATA_DIR`=/app/geoserver/config
- `GEOSERVER_GEODATA_DIR`=/app/geoserver/data
- `GEOSERVER_LOG_DIR`=/app/geoserver/logs
- `GEOSERVER_LOG_LOCATION`=/app/geoserver/logs/geoserver.log
- `GEOWEBCACHE_CONFIG_DIR`=/app/geoserver/gwc/config
- `GEOWEBCACHE_CACHE_DIR`=/app/geoserver/gwc/cache

> IMPORTANT NOTE: Implemented in the environment variables of the docker-compose file.<br />_Implémenté au niveau des variables d'environnements du fichier docker-compose._

### Default user

- `GEOSERVER_ADMIN_USER`=Admin_username
- `GEOSERVER_ADMIN_PASSWORD`=Admin_password

> IMPORTANT NOTE: After the initial setup, it's recommended to remove the GEOSERVER*ADMIN_USER and GEOSERVER_ADMIN_PASSWORD variable. Otherwise, newly added roles and users may be overwritten by the next time the container is restarted.<br />\_Après la configuration initiale, il est recommandé de supprimer les variables GEOSERVER_ADMIN_USER et GEOSERVER_ADMIN_PASSWORD. Dans le cas contraire, les rôles et utilisateurs nouvellement ajoutés risquent d'être écrasés au prochain redémarrage du conteneur.*

### CSRF Protection

The GeoServer web admin employs a CSRF (Cross-Site Request Forgery) protection filter that will block any form submissions that didn’t appear to originate from GeoServer. This can sometimes cause problems for certain proxy configurations.

To allow-list your proxy with the CSRF filter, you can use the GEOSERVER_CSRF_WHITELIST property. This property is a comma-separated list of domains, of the form <domainname>.<TLD>, and can contain a subdomains. Alternatively, you can disable the CSRF filter by setting the GEOSERVER_CSRF_DISABLED property to true.

- `GEOSERVER_CSRF_WHITELIST`=`example.org`
- `GEOSERVER_CSRF_DISABLED`=`false`

### EXTENSIONS

- `INSTALL_EXTENSIONS`=`true`
- `STABLE_EXTENSIONS`=`wps,ysld,dxf`
