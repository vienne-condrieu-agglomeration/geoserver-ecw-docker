# GEOSERVER-ECW Build
```bash
docker build --no-cache=true --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') -t allfab/geoserver-ecw:latest .

docker build -f ./Dockerfile --no-cache=true --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') -t allfab/geoserver-ecw:latest -t allfab/geoserver-ecw:2.26.2 -t allfab/geoserver-ecw:2.26.2-12.9-slim .
```

# Docker run
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

# Delete All allfab/geoserver-ecw images
```bash
docker rmi --force $(docker images -q allfab/geoserver-ecw) 
```