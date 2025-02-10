#!/bin/bash
# 
# startup.sh
#
# (c) Allfab 2025 <allfab@gmail.com>

echo "Welcome to GeoServer $GEOSERVER_VERSION installation script"

# CHANGE DEFAULT ADMIN USER CREDENTIALS
if [ -n "$GEOSERVER_ADMIN_PASSWORD" ] && [ -n "$GEOSERVER_ADMIN_USER" ]; then
    /bin/bash /app/update_credentials.sh
fi

# INSTALL GEOSERVER EXTENSIONS BEFORE STARTING JETTY SERVER
/app/install-extensions.sh

# copy additional geoserver libs before starting jetty server
# we also count whether at least one file with the extensions exists
count=`ls -1 $ADDITIONAL_EXTENSIONS_PATH/*.jar 2>/dev/null | wc -l`
if [ -d "$ADDITIONAL_EXTENSIONS_PATH" ] && [ $count != 0 ]; then
    cp $ADDITIONAL_EXTENSIONS_PATH/*.jar $JETTY_BASE/webapps/geoserver/WEB-INF/lib/
    echo "Installed $count JAR extension file(s) from the additional libs folder"
fi

# Marlin-renderer rasterizer
wget -O $JETTY_BASE/lib/marlin.jar https://github.com/bourgesl/marlin-renderer/releases/download/v0_9_4_8/marlin-0.9.4.8-Unsafe-OpenJDK11.jar

# HTTP/HTTPS
if [ "${HTTPS_ENABLED}" = "true" ]; then
  if [ ! -f "${HTTPS_KEYSTORE_FILE}" ]; then
    echo -e "ERROR: HTTPS was enabled but keystore file was not mounted to container [${HTTPS_KEYSTORE_FILE}]\nAdd volumes ./geoserver/jks/keystore:/srv/jetty/geoserver-base/etc/keystore"
    exit 1
  fi
  cd $JETTY_BASE
  java -jar $JETTY_HOME/start.jar --add-module=server,http,https,ssl,ee8-deploy,ee8-jsp
  echo "Installing Jetty with HTTPS support using substituted environment variables"
  envsubst < "/tmp/jetty/start.d/ssl.ini" > "${JETTY_BASE}/start.d/ssl.ini"
  envsubst < "/tmp/jetty/start.d/https.ini" > "${JETTY_BASE}/start.d/https.ini"
else
  cd $JETTY_BASE
  java -jar $JETTY_HOME/start.jar --add-module=server,http,ee8-deploy,ee8-jsp
fi

# RUN JETTY
cd $JETTY_BASE && java -jar /srv/jetty/start.jar