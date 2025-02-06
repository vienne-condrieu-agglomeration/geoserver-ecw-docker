# GEOSERVER-ECW Build
docker build -f Dockerfile --no-cache=true --build-arg BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ') -t allfab/geoserver-ecw:latest -t allfab/geoserver-ecw:2.26.2 .
docker run -it --name geoserver -p 8080:8080 -d allfab/geoserver-ecw:latest