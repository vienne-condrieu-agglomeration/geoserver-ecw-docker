#!/bin/bash
# 
# startup.sh
#
# (c) Allfab 2025 <allfab@gmail.com>

echo "Welcome to GeoServer $GEOSERVER_VERSION installation script"

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
  java -jar $JETTY_HOME/start.jar --add-module=server,http,ee8-deploy,ee8-jsp
fi

# RUN JETTY
cd $JETTY_BASE && java -jar /srv/jetty/start.jar