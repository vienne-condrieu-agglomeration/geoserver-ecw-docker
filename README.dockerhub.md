# GeoServer with ECW & JP2ECW (JPEG2000) support



<div align="center">

[![Docker Pulls](https://img.shields.io/docker/pulls/allfab/geoserver-ecw)](https://hub.docker.com/r/allfab/geoserver-ecw)

[![Geoserver](https://geoserver.org/img/geoserver-logo.png)](https://geoserver.org/)

</div>

GeoServer image with **ERDAS ECW / JP2ECW** raster support (GDAL + Hexagon native libs), running on Debian Trixie.

> ℹ️ **Full documentation, build instructions and sources:** <https://github.com/vienne-condrieu-agglomeration/geoserver-ecw-docker>
> _Documentation complète, instructions de build et sources sur GitHub (lien ci-dessus)._

Default image (`latest`) :

- Debian `13.6` · OpenJDK `21` · Jetty `12.1.7` · GDAL `3.13.1` · GeoServer `3.0.0`
- Native JAI installed, JAI-EXT enabled, ERDAS ECW / JP2ECW renderer

> ⚠️ **Change the default GeoServer admin password!** The default master password lives (inside the container) at `/app/geoserver/config/security/masterpw/default/masterpw`.<br />_Pensez à changer le mot de passe admin par défaut !_

---

## Supported tags / _Tags disponibles_

Every version ships as `<version>` **and** `<version>-13.6-slim` (same image, alias tag); `3.0.0` also carries `latest`. The `-<debian>-slim` suffix reflects the base image's Debian version.<br />
_Chaque version est publiée en `<version>` **et** `<version>-13.6-slim` (même image, tag alias) ; `3.0.0` porte aussi `latest`._

| Line | Tags |
|---|---|
| GeoServer 3.0 (Java 21 / Jetty 12.1 / Jakarta EE11) | `3.0.0`, `3.0.0-13.6-slim`, `latest` |
| GeoServer 2.28 (Java 21 / Jetty 12.1 / EE8) | `2.28.4`, `2.28.4-13.6-slim` |
| GeoServer 2.17→2.27 (Java 11 / Jetty 10) | `2.27.5`, `2.26.4`, `2.25.7`, `2.24.5`, `2.23.6`, `2.22.6`, `2.21.5`, `2.20.7`, `2.19.7`, `2.18.7`, `2.17.5` (each also `-13.6-slim`) |

> The 13 pinned versions above are built from a single `Dockerfile` (only build-args change). Older Debian-suffixed tags from earlier builds (e.g. `2.28.2-13.4-slim`) may still exist. See the GitHub repo for the full build matrix and per-version commands.<br />_Les 13 versions ci-dessus sont buildées depuis un même `Dockerfile`. D'anciens tags à suffixe Debian peuvent subsister. Matrice complète et commandes par version sur GitHub._

---

## Quick start / _Démarrage rapide_

### Without HTTPS

```bash
docker run -it --name geoserver \
    -e HTTPS_ENABLED=false \
    -p 8080:8080 -d allfab/geoserver-ecw:latest
```

Then open <http://localhost:8080/geoserver/> and log in with the GeoServer defaults `admin:geoserver`.

### With HTTPS (dev/test, self-signed auto-generated)

If no keystore is mounted, a self-signed keystore is auto-generated at startup (dev/test only; default password `geoserver`).<br />
_Si aucun keystore n'est monté, un keystore self-signed est auto-généré au démarrage (dev/test uniquement)._

```bash
docker run -it --name geoserver \
    -e HTTPS_ENABLED=true \
    -p 8080:8080 -p 8443:8443 -d allfab/geoserver-ecw:latest
```

For **production** HTTPS you must provide your own Java keystore (`HTTPS_KEYSTORE_FILE` + `HTTPS_KEYSTORE_PASSWORD`), or — recommended — terminate TLS at a reverse proxy and keep `HTTPS_ENABLED=false`. See the GitHub repo (HTTPS / SSL Keystore section) for the keystore generator and the two TLS termination models.<br />
_Pour l'HTTPS en **production**, fournissez votre propre keystore Java, ou (recommandé) terminez le TLS sur un reverse proxy avec `HTTPS_ENABLED=false`. Détails et générateur de keystore sur GitHub._

---

## Volumes

Create the host folders (owned by `1000:1000`, the container's `jetty` user) before mounting:<br />
_Créez les dossiers hôte (appartenant à `1000:1000`) avant de les monter :_

```bash
mkdir -pv ./geoserver/{config,data/{raster,vector},logs,gwc/{config,cache},jks,additional_extensions} \
  && chown -Rf 1000:1000 ./geoserver
```

| Container path | Role |
|---|---|
| `/app/geoserver/config` | `GEOSERVER_DATA_DIR` (config, security, catalog) |
| `/app/geoserver/data/{raster,vector}` | geo data |
| `/app/geoserver/logs` | logs |
| `/app/geoserver/gwc/{config,cache}` | GeoWebCache |
| `/app/geoserver/additional_extensions` | manually-dropped extension JARs |
| `/srv/jetty/geoserver-base/etc/keystore` | TLS keystore |

---

## Docker Compose

```yml
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
      - ./geoserver/jks/keystore:/srv/jetty/geoserver-base/etc/keystore # prod: your own keystore; omit for dev/test auto-generation
      - ./geoserver/additional_extensions:/app/geoserver/additional_extensions # needed if INSTALL_EXTENSIONS=true
    environment:
      - GEOSERVER_CSRF_WHITELIST=example.org,*.example.org
      - HTTPS_ENABLED=true            # true | false
      - HTTPS_KEYSTORE_FILE=etc/keystore
      - HTTPS_KEYSTORE_PASSWORD=${HTTPS_KEYSTORE_PASSWORD}
      - GEOSERVER_ADMIN_USER=${GEOSERVER_ADMIN_USER}       # optional, else "admin"
      - GEOSERVER_ADMIN_PASSWORD=${GEOSERVER_ADMIN_PASSWORD} # optional, else "geoserver"
      - INSTALL_EXTENSIONS=true       # true | false
      - STABLE_EXTENSIONS=wps,ysld,dxf
    networks:
      - geoserver

networks:
  geoserver:
    name: geoserver
    driver: bridge
```

> After the initial setup, remove `GEOSERVER_ADMIN_USER` / `GEOSERVER_ADMIN_PASSWORD`, otherwise newly-added roles/users get overwritten on restart.<br />_Après la config initiale, retirez ces variables, sinon les rôles/utilisateurs ajoutés sont écrasés au redémarrage._

---

## Environment variables / _Variables d'environnement_

| Variable | Default | Role |
|---|---|---|
| `HTTPS_ENABLED` | `false` | Enable HTTPS (Jetty TLS) |
| `HTTPS_PORT` | `8443` | HTTPS port |
| `HTTPS_KEYSTORE_FILE` | `etc/keystore` | Keystore path inside the container |
| `HTTPS_KEYSTORE_PASSWORD` | `geoserver`¹ | Keystore password |
| `GEOSERVER_ADMIN_USER` | `admin` | Admin username (see warning above) |
| `GEOSERVER_ADMIN_PASSWORD` | `geoserver` | Admin password |
| `GEOSERVER_CSRF_WHITELIST` | — | Comma-separated proxy domains for the CSRF filter |
| `GEOSERVER_CSRF_DISABLED` | `false` | Disable the CSRF filter |
| `INSTALL_EXTENSIONS` | `false` | Download & install extensions at startup |
| `STABLE_EXTENSIONS` | — | CSV of stable extensions (e.g. `wps,ysld,dxf`) |
| `COMMUNITY_EXTENSIONS` | — | CSV of community extensions |

¹ Default only applies to the auto-generated self-signed keystore (dev/test).

The main container user is `jetty` (UID/GID `1000`), running non-root without privilege escalation, home `/srv/jetty/geoserver-base`. Ports: `8080` (HTTP), `8443` (HTTPS).

---

**Full docs, build matrix, migration guide and issues:** <https://github.com/vienne-condrieu-agglomeration/geoserver-ecw-docker>
