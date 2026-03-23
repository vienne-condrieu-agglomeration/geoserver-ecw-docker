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
