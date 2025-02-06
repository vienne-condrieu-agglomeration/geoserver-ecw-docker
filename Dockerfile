ARG BASE_IMAGE="allfab/gdal-ecw:latest"
ARG DEBIAN_FRONTEND="noninteractive"
ARG DEBIAN_VERSION="12.9"
ARG BUILD_DATE

FROM $BASE_IMAGE AS builder

LABEL \
  maintainer="Allfab <allfab@gmail.com>" \
  architecture="amd64/x86_64" \
  desc="Geoserver image with ECW and JP2ECW support running on Debian Bookworm official image" \
  debian-version=$DEBIAN_VERSION \
  org.opencontainers.image.title="geoserver-ecw" \
  org.opencontainers.image.authors="Allfab <allfab@gmail.com>" \
  org.opencontainers.image.description="Geoserver image with ECW and JP2ECW support running on Debian Bookworm official image" \
  org.opencontainers.image.source="https://forgejo.allfabox.fr/allfab/geoserver-ecw-docker" \
  org.opencontainers.image.created=$BUILD_DATE

ENV JETTY_VERSION="12.0.16"
ENV GEOSERVER_VERSION="2.26.2"
ENV GDAL_VERSION="3.10.1"

# SET JETTY CONFIGURATION
ENV JETTY_HOME=/srv/jetty
ENV JETTY_BASE=/srv/jetty/geoserver-base

# SET EXTERNALIZATIONS
ENV GEOSERVER_HOME="/app/geoserver"
ENV GEOSERVER_DATA_DIR="${GEOSERVER_HOME}/config"
ENV GEOSERVER_GEODATA_DIR="${GEOSERVER_HOME}/geo-data"
ENV GEOSERVER_LOG_DIR="${GEOSERVER_HOME}/logs"
ENV GEOSERVER_LOG_LOCATION="${GEOSERVER_LOG_DIR}/geoserver.log"
ENV GEOWEBCACHE_CONFIG_DIR="${GEOSERVER_DATA_DIR}/gwc"
ENV GEOWEBCACHE_CACHE_DIR="${GEOSERVER_HOME}/gwc-cache"
ENV INITIAL_MEMORY="2G"
ENV MAXIMUM_MEMORY="4G"
ENV JAIEXT_ENABLED="true"

# SET GEOSERVER CONFIGURATION
ENV GEOSERVER_OPTS=" \
  -DGEOSERVER_LOG_LOCATION=${GEOSERVER_LOG_LOCATION} \
  -GEOWEBCACHE_CONFIG_DIR =${GEOWEBCACHE_CONFIG_DIR} \
  -DGEOWEBCACHE_CACHE_DIR=${GEOWEBCACHE_CACHE_DIR} \
  -Dorg.geotools.coverage.jaiext.enabled=${JAIEXT_ENABLED} \
  -Dorg.geotools.shapefile.datetime=true \
  -Duser.timezone=Europe/Paris"

  # SET JAVA CONFIGURATION
ENV JAVA_OPTIONS=" \
  -Xms${INITIAL_MEMORY} \
  -Xmx${MAXIMUM_MEMORY} \
  -Djava.awt.headless=true -server \
  -Dfile.encoding=UTF8 \
  -Djavax.servlet.request.encoding=UTF-8 \
  -Djavax.servlet.response.encoding=UTF-8 \
  -XX:SoftRefLRUPolicyMSPerMB=36000 \
  -XX:+UseG1GC \
  -XX:MaxGCPauseMillis=200 \
  -XX:ParallelGCThreads=20 \
  -XX:ConcGCThreads=5 \
  -Djava.io.tmpdir=/srv/jetty/geoserver-base/tmp \
  -Djava.library.path=/usr/local/lib:/usr/local/hexagon:/usr/local/hexagon/lib/x64/release \  
  -DLD_LIBRARY_PATH=/usr/local/lib:/usr/local/hexagon:/usr/local/hexagon/lib/x64/release \
  ${GEOSERVER_OPTS}"

# SET JAVA CONFIGURATION
ENV JAVA_OPTIONS=" \
  -Xms${INITIAL_MEMORY} \
  -Xmx${MAXIMUM_MEMORY} \
  -Djava.awt.headless=true -server \
  -Dfile.encoding=UTF8 \
  -Djavax.servlet.request.encoding=UTF-8 \
  -Djavax.servlet.response.encoding=UTF-8 \
  -XX:SoftRefLRUPolicyMSPerMB=36000 \
  -XX:+UseG1GC \
  -XX:MaxGCPauseMillis=200 \
  -XX:ParallelGCThreads=20 \
  -XX:ConcGCThreads=5 \
  -Djava.io.tmpdir=/srv/jetty/geoserver-base/tmp \
  -Djava.library.path=/usr/local/lib:/usr/local/hexagon:/usr/local/hexagon/lib/x64/release \  
  -DLD_LIBRARY_PATH=/usr/local/lib:/usr/local/hexagon:/usr/local/hexagon/lib/x64/release \
  ${GEOSERVER_OPTS}"

# CREATE jetty USER
RUN groupadd --system jetty \
    && useradd --system -g jetty --no-create-home jetty \
    && usermod -c "Jetty" -d /app/jetty --gid jetty jetty

# CREATE & SHARE VOLUMES
RUN mkdir -p \
    "${GEOSERVER_HOME}" \
    "${GEOSERVER_DATA_DIR}" \
    "${GEOSERVER_GEODATA_DIR}" \
    "${GEOSERVER_LOG_DIR}"  \
    "${GEOWEBCACHE_CONFIG_DIR}" \
    "${GEOWEBCACHE_CACHE_DIR}"
VOLUME ${GEOSERVER_DATA_DIR}
VOLUME ${GEOSERVER_GEODATA_DIR}
VOLUME ${GEOSERVER_LOG_DIR}
VOLUME ${GEOWEBCACHE_CONFIG_DIR}
VOLUME ${GEOWEBCACHE_CACHE_DIR}

# PREREQUISITE
RUN apt-get update -y \
    &&  apt-get install -y --no-install-recommends wget unzip \
    &&  rm -rf /var/lib/apt/lists/*

# INSTALL JETTY + USER
WORKDIR ${JETTY_HOME}
RUN wget https://repo1.maven.org/maven2/org/eclipse/jetty/jetty-home/$JETTY_VERSION/jetty-home-$JETTY_VERSION.tar.gz \
    && tar xzf jetty-home-$JETTY_VERSION.tar.gz -C ${JETTY_HOME} --strip-components=1 \
    && rm -f ../jetty-home-$JETTY_VERSION.tar.gz \
    && mkdir -p ${JETTY_BASE} ${JETTY_BASE}/webapps ${JETTY_BASE}/tmp \
    && cd ${JETTY_BASE} \
    && chown -R jetty:jetty ${JETTY_HOME} \
    && java -jar "$JETTY_HOME/start.jar" --add-module=server,http,ee8-deploy,ee8-jsp

# INSTALL GEOSERVER
WORKDIR ${JETTY_BASE}/webapps
RUN wget https://kumisystems.dl.sourceforge.net/project/geoserver/GeoServer/$GEOSERVER_VERSION/geoserver-$GEOSERVER_VERSION-war.zip \
    && unzip geoserver-$GEOSERVER_VERSION-war.zip \
    && unzip geoserver.war -d geoserver \
    && rm -Rf README.html geoserver-$GEOSERVER_VERSION-war.zip license target geoserver.war \
    && chown -R jetty:jetty ${JETTY_BASE}

# GDAL NATIVE LIB
RUN cp -f /opt/gdal-${GDAL_VERSION}/java/gdal-${GDAL_VERSION}.jar ${JETTY_BASE}/webapps/geoserver/WEB-INF/lib

# GDAL GEOSERVER EXT LIB
WORKDIR /app/downloads
RUN wget https://deac-fra.dl.sourceforge.net/project/geoserver/GeoServer/$GEOSERVER_VERSION/extensions/geoserver-$GEOSERVER_VERSION-gdal-plugin.zip \
    && unzip geoserver-$GEOSERVER_VERSION-gdal-plugin.zip -d geoserver-$GEOSERVER_VERSION-gdal-plugin \
    && cd geoserver-$GEOSERVER_VERSION-gdal-plugin \
    && cp -f imageio-ext-* ${JETTY_BASE}/webapps/geoserver/WEB-INF/lib \
    && cp -f gs-gdal-$GEOSERVER_VERSION.jar gt-imageio-ext-gdal-*.jar ${JETTY_BASE}/webapps/geoserver/WEB-INF/lib

# GEOSERVER Java Advanced Imaging (JAI)
# https://docs.geoserver.geo-solutions.it/edu/en/install_run/jai_io_install.html
# TO DO OR NOT

WORKDIR ${JETTY_BASE}
RUN chown -Rf jetty:jetty ${JETTY_BASE}/* \
    && rm -Rf /app/downloads
EXPOSE 8080
CMD ["java","-jar","/srv/jetty/start.jar"]
