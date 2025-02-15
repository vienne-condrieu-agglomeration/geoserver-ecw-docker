ARG BASE_IMAGE="allfab/gdal-ecw:latest"

FROM $BASE_IMAGE AS builder

# BUILD ARGUMENTS
ARG DEBIAN_FRONTEND="noninteractive"
ARG BUILD_DATE
ARG GS_VERSION=2.26.2
ARG JAI_VERSION=1.1.28
ARG COMMUNITY_PLUGIN_URL=''
ARG STABLE_PLUGIN_URL=https://downloads.sourceforge.net/project/geoserver/GeoServer/${GS_VERSION}/extensions

LABEL \
  maintainer="Allfab <allfab@gmail.com>" \
  architecture="amd64/x86_64" \
  desc="Geoserver image with ECW and JP2ECW support running on Debian Bookworm official image" \
  org.opencontainers.image.title="geoserver-ecw" \
  org.opencontainers.image.authors="Allfab <allfab@gmail.com>" \
  org.opencontainers.image.description="Geoserver image with ECW and JP2ECW support running on Debian Bookworm official image" \
  org.opencontainers.image.source="https://forgejo.allfabox.fr/allfab/geoserver-ecw-docker" \
  org.opencontainers.image.created=$BUILD_DATE

ENV JETTY_VERSION=12.0.16
ENV GEOSERVER_VERSION=$GS_VERSION
ENV GDAL_VERSION=3.10.2
ENV JAI_RELEASE=$JAI_VERSION
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64

# SET JETTY CONFIGURATION
ENV JETTY_HOME=/srv/jetty
ENV JETTY_BASE=/srv/jetty/geoserver-base

# SET EXTERNALIZATIONS
ENV GEOSERVER_HOME="/app/geoserver"
ENV GEOSERVER_DATA_DIR="$GEOSERVER_HOME/config"
ENV GEOSERVER_GEODATA_DIR="$GEOSERVER_HOME/data"
ENV GEOSERVER_GEODATA_DIR_RASTER="$GEOSERVER_HOME/data/raster"
ENV GEOSERVER_GEODATA_DIR_VECTOR="$GEOSERVER_HOME/data/vector"
ENV GEOSERVER_LOG_DIR="$GEOSERVER_HOME/logs"
ENV GEOSERVER_LOG_LOCATION="$GEOSERVER_LOG_DIR/geoserver.log"
ENV GEOWEBCACHE_CONFIG_DIR="$GEOSERVER_HOME/gwc/config"
ENV GEOWEBCACHE_CACHE_DIR="$GEOSERVER_HOME/gwc/cache"
ENV GEOSERVER_JAVA_KEYSTORE="$JETTY_BASE/etc"
ENV GEOSERVER_LIB_DIR=$JETTY_BASE/webapps/geoserver/WEB-INF/lib/
ENV ADDITIONAL_EXTENSIONS_PATH="$GEOSERVER_HOME/additional_extensions"
ENV INITIAL_MEMORY="2G"
ENV MAXIMUM_MEMORY="4G"
ENV JAIEXT_ENABLED="true"
ENV GEOSERVER_CSRF_WHITELIST=""
ENV GEOSERVER_CSRF_DISABLED=false
ENV STABLE_EXTENSIONS=""
ENV STABLE_PLUGIN_URL=$STABLE_PLUGIN_URL
ENV COMMUNITY_EXTENSIONS=""

ENV HTTPS_ENABLED=false
ENV HTTPS_PORT=8443
ENV HTTPS_KEYSTORE_FILE=etc/keystore
ENV HTTPS_KEYSTORE_PASSWORD="changeit"
ENV HTTPS_KEY_ALIAS=""

# SET GEOSERVER CONFIGURATION
ENV GEOSERVER_OPTS=" \
  -DGEOSERVER_DATA_DIR=$GEOSERVER_DATA_DIR \
  -DGEOSERVER_LOG_LOCATION=$GEOSERVER_LOG_LOCATION \
  -GEOWEBCACHE_CONFIG_DIR =$GEOWEBCACHE_CONFIG_DIR \
  -DGEOWEBCACHE_CACHE_DIR=$GEOWEBCACHE_CACHE_DIR \
  -DGEOSERVER_CSRF_WHITELIST=$GEOSERVER_CSRF_WHITELIST \
  -DGEOSERVER_CSRF_DISABLED=$GEOSERVER_CSRF_DISABLED \
  -Dorg.geotools.coverage.jaiext.enabled=$JAIEXT_ENABLED \
  -Dorg.geotools.shapefile.datetime=true \
  -Duser.timezone=Europe/Paris"

# SET JAVA CONFIGURATION
ENV JAVA_OPTIONS=" \
  --add-exports=java.desktop/sun.awt.image=ALL-UNNAMED \
  --add-opens=java.base/java.lang=ALL-UNNAMED \
  --add-opens=java.base/java.util=ALL-UNNAMED \
  --add-opens=java.base/java.lang.reflect=ALL-UNNAMED \
  --add-opens=java.base/java.text=ALL-UNNAMED \
  --add-opens=java.desktop/java.awt.font=ALL-UNNAMED \
  --add-opens=java.desktop/sun.awt.image=ALL-UNNAMED \
  --add-opens=java.naming/com.sun.jndi.ldap=ALL-UNNAMED \
  --add-opens=java.desktop/sun.java2d.pipe=ALL-UNNAMED \
  -Djava.awt.headless=true -server \
  -Dfile.encoding=UTF-8 \
  -Djavax.servlet.request.encoding=UTF-8 \
  -Djavax.servlet.response.encoding=UTF-8 \
  -D-XX:SoftRefLRUPolicyMSPerMB=36000 \
  -Xbootclasspath/a:$JETTY_HOME/lib/marlin.jar \
  -Dsun.java2d.renderer=sun.java2d.marlin.DMarlinRenderingEngine \
  -Dorg.geotools.coverage.jaiext.enabled=true \
  -Xms$INITIAL_MEMORY \
  -Xmx$MAXIMUM_MEMORY \
  -XX:SoftRefLRUPolicyMSPerMB=36000 \
  -XX:+UseG1GC \
  -XX:MaxGCPauseMillis=200 \
  -XX:ParallelGCThreads=20 \
  -XX:ConcGCThreads=5 \
  -Djava.io.tmpdir=/srv/jetty/geoserver-base/tmp \
  -Djava.library.path=/usr/local/lib:/usr/local/hexagon:/usr/local/hexagon/lib/x64/release \  
  -DLD_LIBRARY_PATH=/usr/local/lib:/usr/local/hexagon:/usr/local/hexagon/lib/x64/release \
  $GEOSERVER_OPTS"
 
USER root

# CREATE jetty USER AND DELETE gdal USER FROM allfab/gdal-ecw IMAGE
ARG USERNAME=jetty
ARG USER_UID=1000
ARG USER_GID=$USER_UID
RUN userdel -r gdal \
    && rm -Rf /app/gdal \
    && groupadd --system --gid $USER_GID $USERNAME \
    && useradd --system --uid $USER_UID --gid $USER_GID --no-create-home $USERNAME \
    && usermod -c $USERNAME --home $JETTY_BASE $USERNAME \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

# CREATE & SHARE VOLUMES
RUN mkdir -p \
    $GEOSERVER_HOME \
    $GEOSERVER_DATA_DIR \
    $GEOSERVER_GEODATA_DIR \
    $GEOSERVER_GEODATA_DIR_RASTER \
    $GEOSERVER_GEODATA_DIR_VECTOR \
    $GEOSERVER_LOG_DIR  \
    $GEOWEBCACHE_CONFIG_DIR \
    $GEOWEBCACHE_CACHE_DIR \
    $ADDITIONAL_EXTENSIONS_PATH \
    && chown -Rf jetty:jetty $GEOSERVER_HOME

VOLUME $GEOSERVER_DATA_DIR
VOLUME $GEOSERVER_GEODATA_DIR_RASTER
VOLUME $GEOSERVER_GEODATA_DIR_VECTOR
VOLUME $GEOSERVER_LOG_DIR
VOLUME $GEOWEBCACHE_CONFIG_DIR
VOLUME $GEOWEBCACHE_CACHE_DIR
VOLUME $GEOSERVER_JAVA_KEYSTORE
VOLUME $ADDITIONAL_EXTENSIONS_PATH

# PREREQUISITE + PERMISSIONS
WORKDIR $JETTY_HOME
RUN apt-get update -y \
    && apt-get install -y --no-install-recommends wget unzip gettext-base \
    && rm -rf /var/lib/apt/lists/*

# INSTALL JETTY
RUN wget --progress=dot:giga https://repo1.maven.org/maven2/org/eclipse/jetty/jetty-home/$JETTY_VERSION/jetty-home-$JETTY_VERSION.tar.gz \
    && tar xzf jetty-home-$JETTY_VERSION.tar.gz -C $JETTY_HOME --strip-components=1 \
    && rm -f ../jetty-home-$JETTY_VERSION.tar.gz \
    && mkdir -p $JETTY_BASE $JETTY_BASE/webapps $JETTY_BASE/tmp \
    && cd $JETTY_BASE \
    && chown -R jetty:jetty $JETTY_HOME

# INSTALL GEOSERVER
WORKDIR $JETTY_BASE/webapps
RUN wget --progress=dot:giga https://kumisystems.dl.sourceforge.net/project/geoserver/GeoServer/$GEOSERVER_VERSION/geoserver-$GEOSERVER_VERSION-war.zip \
    && unzip geoserver-$GEOSERVER_VERSION-war.zip \
    && unzip geoserver.war -d geoserver \
    && rm -Rf README.html geoserver-$GEOSERVER_VERSION-war.zip license target geoserver.war \
    && chown -R jetty:jetty $JETTY_BASE

# GDAL NATIVE LIB + ADDITIONAL GEOSERVER EXTENSIONS
RUN cp -f /opt/gdal-$GDAL_VERSION/java/gdal-$GDAL_VERSION.jar $JETTY_BASE/webapps/geoserver/WEB-INF/lib

# GDAL GEOSERVER EXT LIB
WORKDIR /tmp/downloads
RUN wget --progress=dot:giga https://deac-fra.dl.sourceforge.net/project/geoserver/GeoServer/$GEOSERVER_VERSION/extensions/geoserver-$GEOSERVER_VERSION-gdal-plugin.zip \
    && unzip geoserver-$GEOSERVER_VERSION-gdal-plugin.zip -d geoserver-$GEOSERVER_VERSION-gdal-plugin \
    && cd geoserver-$GEOSERVER_VERSION-gdal-plugin \
    && cp -f imageio-ext-* $JETTY_BASE/webapps/geoserver/WEB-INF/lib \
    && cp -f gs-gdal-$GEOSERVER_VERSION.jar gt-imageio-ext-gdal-*.jar $JETTY_BASE/webapps/geoserver/WEB-INF/lib

COPY jetty/start.d /tmp/jetty/start.d
COPY *.sh /app

RUN chmod +x /app/startup.sh && sed -i 's/\r$//' /app/startup.sh \
  && chmod +x /app/update-credentials.sh && sed -i 's/\r$//' /app/update-credentials.sh \
  && chmod +x /app/install-extensions.sh && sed -i 's/\r$//' /app/install-extensions.sh

WORKDIR $JETTY_BASE
USER jetty
ENTRYPOINT ["bash", "/app/startup.sh"]

EXPOSE 8080
EXPOSE 8443
