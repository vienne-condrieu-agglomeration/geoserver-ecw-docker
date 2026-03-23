# Geoserver image with ECW and JP2ECW support running on Debian Trixie official image

<div align="center">

[![status-badge](https://forgejo.ci.allfabox.fr/api/badges/2/status.svg)](https://forgejo.ci.allfabox.fr/repos/2)
[![Docker Pulls](https://img.shields.io/docker/pulls/allfab/geoserver-ecw)](https://hub.docker.com/r/allfab/geoserver-ecw)

[![Geoserver](https://geoserver.org/img/geoserver-logo.png)](https://geoserver.org/)

</div>

- Debian based Linux `13.4`
- OpenJDK `21`
- Jetty `12.1.7`
- GDAL `3.12.3`
- Geoserver `2.28.2` :
  - Native Java advanced imaging (JAI) is installed
  - JAI-EXT⁠ is enabled by default
  - ERDAS ECW and JP2ECW (JPG2000) renderer

> IMPORTANT NOTE: Please change the default geoserver admin password ! The default masterpw is located in this file (within the docker container): /app/geoserver/config/security/masterpw/default/masterpw

## Supported tags and respective `Dockerfile` links

- [`2.28.2` - `2.28.2-13.4-slim` - `latest`⁠](https://forgejo.allfabox.fr/allfab/geoserver-ecw-docker/src/branch/main/Dockerfile)
- [`2.27.2` - `2.27.2-13.1-slim`⁠](https://forgejo.allfabox.fr/allfab/geoserver-ecw-docker/src/branch/main/Dockerfile)
- [`2.27.1` - `2.27.1-12.11-slim`⁠](https://forgejo.allfabox.fr/allfab/geoserver-ecw-docker/src/branch/main/Dockerfile)

---

| Tag                                    | Description                                                                                  |
| -------------------------------------- | -------------------------------------------------------------------------------------------- |
| `latest`                               | [Latest release version](https://forgejo.allfabox.fr/allfab/geoserver-ecw-docker/)           |
| `2.28.2`, `2.28.2-13.4-slim`, `latest` | [Geoserver 2.28.2 Release Notes](https://github.com/geoserver/geoserver/releases/tag/2.28.2) |
| `2.27.2`, `2.27.2-13.1-slim`           | [Geoserver 2.27.2 Release Notes](https://github.com/geoserver/geoserver/releases/tag/2.27.2) |
| `2.27.1`, `2.27.1-12.11-slim`          | [Geoserver 2.27.1 Release Notes](https://github.com/geoserver/geoserver/releases/tag/2.27.1) |

## What is Geoserver ?

## How to build ?

```bash
docker build -f ./Dockerfile --no-cache=true --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') -t allfab/geoserver-ecw:latest -t allfab/geoserver-ecw:2.28.2 -t allfab/geoserver-ecw:2.28.2-13.4-slim .
```

```bash
docker build -f ./Dockerfile --no-cache=true --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') -t allfab/geoserver-ecw:latest -t allfab/geoserver-ecw:2.27.2 -t allfab/geoserver-ecw:2.27.2-13.1-slim .
```

## How to quickstart ?

### Volumes

In order to manage the correct permissions on the directories mounted as a volume on the `geoserver` container, you must first create the structure of the folders that will host the Geoserver data.<br />
_Afin de gérer les bonnes permissions sur les répertoires montés en volume sur le container `geoserver`, il faut au préalable créer la structure des dossiers qui vont accueillir les données de Geoserver_

```bash
mkdir -pv ./geoserver/{config,data/{raster,vector},logs,gwc/{config,cache},jks,additional_extensions} \
&& chown -Rf 1000:1000 ./geoserver
```

```bash
tree -L 3 geoserver
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

11 directories, 1 file
```

### HTTPS / SSL Keystore

When `HTTPS_ENABLED=true`, the container needs a Java keystore for TLS. Two modes are available:<br />
_Quand `HTTPS_ENABLED=true`, le conteneur a besoin d'un keystore Java pour TLS. Deux modes sont disponibles :_

**Auto-generated self-signed keystore (dev/test)** : If no keystore file is mounted, the container will **automatically generate a self-signed keystore** at startup. This is convenient for development and testing but **should NOT be used in production**. If `HTTPS_KEYSTORE_PASSWORD` is not provided, it defaults to `geoserver`. The auto-generated keystore only creates a self-signed certificate - browsers will show a security warning.<br />
_**Keystore self-signed auto-généré (dev/test)** : Si aucun fichier keystore n'est monté, le conteneur **génère automatiquement un keystore self-signed** au démarrage. C'est pratique pour le développement et les tests mais **ne doit PAS être utilisé en production**. Si `HTTPS_KEYSTORE_PASSWORD` n'est pas fourni, il vaut par défaut `geoserver`. Le keystore auto-généré ne crée qu'un certificat self-signed - les navigateurs afficheront un avertissement de sécurité._

**Custom keystore (production)** : For production, generate your own keystore with a real SSL certificate and mount it in the container. Put the keystore file in the `jks` folder and provide the password via `HTTPS_KEYSTORE_PASSWORD`. The production script below performs 3 steps that the auto-generated keystore does not:<br />
_**Keystore personnalisé (production)** : En production, générez votre propre keystore avec un vrai certificat SSL et montez-le dans le conteneur. Placez le fichier keystore dans le dossier `jks` et fournissez le mot de passe via `HTTPS_KEYSTORE_PASSWORD`. Le script de production ci-dessous effectue 3 étapes que le keystore auto-généré ne fait pas :_

| | Auto-generated (dev/test) | keystore-generator.sh (production) |
|---|---|---|
| Private key + self-signed cert / _Clé privée + cert self-signed_ | Yes / _Oui_ | Yes / _Oui_ |
| Import Java cacerts (outbound TLS trust) / _Import cacerts Java (confiance TLS sortant)_ | No / _Non_ | Yes / _Oui_ |
| Import real SSL certificate / _Import vrai certificat SSL_ | No / _Non_ | Yes / _Oui_ |
| Accepted by browsers / _Accepté par les navigateurs_ | No / _Non_ | Yes / _Oui_ |

```bash
#!/bin/bash
# keystore-generator.sh
#
# "mypassword"  = password for YOUR keystore (use this value for HTTPS_KEYSTORE_PASSWORD at runtime)
# "changeit"    = default password for Java system cacerts (do not change)
#
# "mypassword"  = mot de passe de VOTRE keystore (à utiliser pour HTTPS_KEYSTORE_PASSWORD au runtime)
# "changeit"    = mot de passe par défaut du cacerts système Java (ne pas modifier)

# Step 1: Create keystore with a private key and self-signed certificate
# Étape 1 : Créer le keystore avec une clé privée et un certificat self-signed
keytool -genkey \
    -alias geoserver_localhost \
    -keystore ./keystore \
    -deststoretype pkcs12 \
    -storepass mypassword \
    -keypass mypassword \
    -keyalg RSA \
    -keysize 2048 \
    -dname "CN=geoserver.mydomain.com, OU=geoserver.mydomain.com, O=Unknown, L=Unknown, ST=Unknown, C=FR"

# Step 2: Import Java system trusted root certificates (cacerts) into your keystore.
#         This allows GeoServer to validate outbound TLS connections (e.g. cascaded WMS, external services).
#         "changeit" is the default password of Java's system cacerts - do not change it.
#
# Étape 2 : Importer les certificats racine de confiance Java (cacerts) dans votre keystore.
#           Cela permet à GeoServer de valider les connexions TLS sortantes (ex: WMS cascadé, services externes).
#           "changeit" est le mot de passe par défaut du cacerts système Java - ne pas le modifier.

# ON RHEL BASE
# printf '<dest keystore password>\n<source cacerts password>\n'
printf 'mypassword\nchangeit\n' | keytool -importkeystore \
    -srckeystore /etc/pki/java/cacerts \
    -destkeystore ./keystore \
    -deststoretype pkcs12

# ON DEBIAN/UBUNTU BASE
# printf '<dest keystore password>\n<source cacerts password>\n'
printf 'mypassword\nchangeit\n' | keytool -importkeystore \
    -srckeystore /etc/ssl/certs/java/cacerts \
    -destkeystore ./keystore \
    -deststoretype pkcs12

# Step 3: Import your real SSL certificate so browsers accept the HTTPS connection.
# Étape 3 : Importer votre vrai certificat SSL pour que les navigateurs acceptent la connexion HTTPS.
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

> **NOTE:** If no keystore file is mounted, a self-signed keystore is auto-generated at startup (for dev/test only). For production, mount your own keystore and provide the password via `HTTPS_KEYSTORE_PASSWORD`.<br />_Si aucun fichier keystore n'est monté, un keystore self-signed est auto-généré au démarrage (dev/test uniquement). En production, montez votre propre keystore et fournissez le mot de passe via `HTTPS_KEYSTORE_PASSWORD`._

With auto-generated self-signed keystore (dev/test) :

```bash
docker run -it --name geoserver \
    -e HTTPS_ENABLED=true \
    -p 8080:8080 -p 8443:8443 -d allfab/geoserver-ecw:latest
```

With custom keystore (production) :

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

### With all options (dev/test - localhost)

Use this for local development and testing. A self-signed keystore is auto-generated, no need to create one manually. The browser will show a security warning on HTTPS, this is expected.<br />
_Utilisez ceci pour le développement et les tests en local. Un keystore self-signed est auto-généré, pas besoin d'en créer un manuellement. Le navigateur affichera un avertissement de sécurité sur HTTPS, c'est normal._

```bash
docker run -it --name geoserver \
    -e GEOSERVER_CSRF_WHITELIST=localhost \
    -e HTTPS_ENABLED=true \
    -e GEOSERVER_ADMIN_USER=admindemo \
    -e GEOSERVER_ADMIN_PASSWORD=demodemo \
    -e INSTALL_EXTENSIONS=true \
    -e STABLE_EXTENSIONS=wps,ysld,dxf \
    -v ./geoserver/config:/app/geoserver/config \
    -v ./geoserver/data/raster:/app/geoserver/data/raster \
    -v ./geoserver/data/vector:/app/geoserver/data/vector \
    -v ./geoserver/logs:/app/geoserver/logs \
    -v ./geoserver/gwc/config:/app/geoserver/gwc/config \
    -v ./geoserver/gwc/cache:/app/geoserver/gwc/cache \
    -v ./geoserver/additional_extensions:/app/geoserver/additional_extensions \
    -p 8080:8080 -p 8443:8443 -d allfab/geoserver-ecw:latest
```

- [http://localhost:8080/geoserver/](http://localhost:8080/geoserver/)
- [https://localhost:8443/geoserver/](https://localhost:8443/geoserver/) (self-signed certificate warning)

### With all options (production)

Use this for production deployments. You **must** generate your own keystore beforehand (see [HTTPS / SSL Keystore](#https--ssl-keystore) section) and mount it in the container. Replace `example.org` with your actual domain.<br />
_Utilisez ceci pour les déploiements en production. Vous **devez** générer votre propre keystore au préalable (voir la section [HTTPS / SSL Keystore](#https--ssl-keystore)) et le monter dans le conteneur. Remplacez `example.org` par votre domaine réel._

```bash
docker run -it --name geoserver \
    -e GEOSERVER_CSRF_WHITELIST=example.org,*.example.org \
    -e HTTPS_ENABLED=true \
    -e HTTPS_KEYSTORE_FILE=etc/keystore \
    -e HTTPS_KEYSTORE_PASSWORD=mypassword \
    -e GEOSERVER_ADMIN_USER=admindemo \
    -e GEOSERVER_ADMIN_PASSWORD=demodemo \
    -e INSTALL_EXTENSIONS=true \
    -e STABLE_EXTENSIONS=wps,ysld,dxf \
    -v ./geoserver/config:/app/geoserver/config \
    -v ./geoserver/data/raster:/app/geoserver/data/raster \
    -v ./geoserver/data/vector:/app/geoserver/data/vector \
    -v ./geoserver/logs:/app/geoserver/logs \
    -v ./geoserver/gwc/config:/app/geoserver/gwc/config \
    -v ./geoserver/gwc/cache:/app/geoserver/gwc/cache \
    -v ./geoserver/jks/keystore:/srv/jetty/geoserver-base/etc/keystore \
    -v ./geoserver/additional_extensions:/app/geoserver/additional_extensions \
    -p 8080:8080 -p 8443:8443 -d allfab/geoserver-ecw:latest
```

Check [http://localhost:8080/geoserver/](http://localhost:8080/geoserver/) to see the geoserver application page and login with geoserver defaults credentials :

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
      - ./geoserver/jks/keystore:/srv/jetty/geoserver-base/etc/keystore # Production: mount your own keystore. If omitted, a self-signed keystore is auto-generated (dev/test only)
      - ./geoserver/additional_extensions:/app/geoserver/additional_extensions # Needed if INSTALL_EXTENSIONS=true
    environment:
      - GEOSERVER_CSRF_WHITELIST=example.org,*.example.org
      - HTTPS_ENABLED=true # REQUIRE : true | false
      - HTTPS_KEYSTORE_FILE=etc/keystore # Needed if HTTPS_ENABLED=true, keystore file mounted on container
      - HTTPS_KEYSTORE_PASSWORD=${HTTPS_KEYSTORE_PASSWORD} # Required for custom keystore. If omitted with no keystore mounted, defaults to "geoserver"
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

# HTTPS
HTTPS_KEYSTORE_PASSWORD="mypassword"

# GEOSERVER
GEOSERVER_ADMIN_USER="myuser"
GEOSERVER_ADMIN_PASSWORD="mypassword"
```

## Users

The main user of this container is named `jetty` and its default directory is `/srv/jetty/geoserver-base`. It runs as a non-root user without privilege escalation.<br />
_L'utilisateur principal de ce container se nomme `jetty` et son répertoire par défaut est `/srv/jetty/geoserver-base`. Il s'exécute en tant qu'utilisateur non-root sans escalade de privilèges._

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

### HTTPS

- `HTTPS_ENABLED`=`false` - Enable HTTPS support / _Activer le support HTTPS_
- `HTTPS_PORT`=`8443` - HTTPS port / _Port HTTPS_
- `HTTPS_KEYSTORE_FILE`=`etc/keystore` - Path to the keystore file inside the container / _Chemin du fichier keystore dans le conteneur_
- `HTTPS_KEYSTORE_PASSWORD` - Keystore password. If not provided and no keystore is mounted, defaults to `geoserver` when a self-signed keystore is auto-generated / _Mot de passe du keystore. Si non fourni et aucun keystore monté, vaut `geoserver` par défaut lors de l'auto-génération du keystore self-signed_

> **NOTE:** If no keystore file is mounted when `HTTPS_ENABLED=true`, a self-signed keystore is automatically generated for development/testing. For production, always mount your own keystore and provide `HTTPS_KEYSTORE_PASSWORD`.<br />_Si aucun fichier keystore n'est monté quand `HTTPS_ENABLED=true`, un keystore self-signed est automatiquement généré pour le développement/test. En production, montez toujours votre propre keystore et fournissez `HTTPS_KEYSTORE_PASSWORD`._

### CSRF Protection

The GeoServer web admin employs a CSRF (Cross-Site Request Forgery) protection filter that will block any form submissions that didn’t appear to originate from GeoServer. This can sometimes cause problems for certain proxy configurations.

To allow-list your proxy with the CSRF filter, you can use the GEOSERVER_CSRF_WHITELIST property. This property is a comma-separated list of domains, of the form <domainname>.<TLD>, and can contain a subdomains. Alternatively, you can disable the CSRF filter by setting the GEOSERVER_CSRF_DISABLED property to true.

- `GEOSERVER_CSRF_WHITELIST`=`example.org`
- `GEOSERVER_CSRF_DISABLED`=`false`

### EXTENSIONS

- `INSTALL_EXTENSIONS`=`true`
- `STABLE_EXTENSIONS`=`wps,ysld,dxf`
