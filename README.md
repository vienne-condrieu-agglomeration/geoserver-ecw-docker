# Geoserver image with ECW and JP2ECW support running on Debian Bookworm official image

- Debian based Linux
- OpenJDK12
- Jetty 12
- GDAL 3.9.2
- Geoserver :
   - Native Java advanced imaging (JAI) is installed
   - JAI-EXT⁠ is enabled by default
   - ERDAS ECW and JP2ECW (JPG2000) renderer

> IMPORTANT NOTE: Please change the default geoserver admin password ! The default masterpw is located in this file (within the docker container): /app/geoserver/config/security/masterpw/default/masterpw

# Supported tags and respective Dockerfile links
- [`2.25.3-debian12.7`](http://github.com)

# How to build ?

## Debian 12.7

### GDAL 3.9.2
```bash
docker build -f gdal/build/debian/12.7/Dockerfile -t allfab/gdal:3.9.2-debian12.7 gdal/.
```
### Geoserver 2.25.3
```bash
docker build -f geoserver/build/debian/2.25.3/Dockerfile -t allfab/geoserver:2.25.3-debian12.7 geoserver/.
docker run -it --name geoserver -d allfab/geoserver:2.25.3-debian12.7
```

# How to quickstart ?

## Docker compose
```yml
---
services:
  geoserver:
    container_name: geoserver
    image: allfab/geoserver:2.25.3-debian12.7
    restart: unless-stopped
    ports:
      - 8080:8080
    volumes:
      - ./config:/app/geoserver/config
      - ./data:/app/geoserver/geo-data
      - ./gwc-cache:/app/geoserver/gwc-cache
    networks:
      - geoserver

networks:
  geoserver:
    name: geoserver
    driver: bridge
    ipam:
      config:
        - subnet: "172.19.0.0/16"
          gateway: "172.19.0.1"
```

Check [http://localhost:8080/geoserver/⁠](http://localhost:8080/geoserver/) to see the geoserver application page and login with geoserver defaults credentials :

> `admin:geoserver`

## Docker run
```bash
docker run
```