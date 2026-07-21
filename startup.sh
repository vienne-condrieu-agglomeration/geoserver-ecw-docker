#!/bin/bash
# 
# startup.sh
#
# (c) Allfab 2025 <allfab@gmail.com>

echo "Welcome to GeoServer $GEOSERVER_VERSION installation script"

# CHANGE DEFAULT ADMIN USER CREDENTIALS
if [ -n "$GEOSERVER_ADMIN_PASSWORD" ] && [ -n "$GEOSERVER_ADMIN_USER" ]; then
    /bin/bash /app/update-credentials.sh
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

# SELECT JETTY WEBAPP DEPLOY MODULES ACCORDING TO THE RUNTIME PROFILE
#  - jetty10-javax : Jetty 10 (Java 11 tier), non-namespaced javax modules  -> GeoServer 2.16..2.27
#  - jetty12-ee10  : Jetty 12, Jakarta EE modules                           -> GeoServer 3.x
#  - jetty12-ee8   : Jetty 12, javax EE8 compat modules (default)           -> GeoServer 2.28
case "${SERVLET_PROFILE}" in
  jetty10-javax) DEPLOY_MODULES="deploy,jsp" ;;
  jetty12-ee11)  DEPLOY_MODULES="ee11-deploy,ee11-jsp" ;;
  jetty12-ee10)  DEPLOY_MODULES="ee10-deploy,ee10-jsp" ;;
  *)             DEPLOY_MODULES="ee8-deploy,ee8-jsp" ;;
esac
echo "Using Jetty deploy modules: ${DEPLOY_MODULES} (SERVLET_PROFILE=${SERVLET_PROFILE:-jetty12-ee8})"

# HTTP/HTTPS
if [ "${HTTPS_ENABLED}" = "true" ]; then
  cd $JETTY_BASE

  # If no keystore file is mounted, auto-generate a self-signed keystore for dev/test
  if [ ! -f "${HTTPS_KEYSTORE_FILE}" ]; then
    echo "WARNING: HTTPS is enabled but no keystore file was mounted to [${HTTPS_KEYSTORE_FILE}]"
    echo "Auto-generating a self-signed keystore for development/testing purposes..."
    echo "WARNING: Do NOT use this in production! Mount your own keystore via:"
    echo "  -v ./geoserver/jks/keystore:/srv/jetty/geoserver-base/etc/keystore"

    # Use HTTPS_KEYSTORE_PASSWORD if provided, otherwise default to "geoserver"
    HTTPS_KEYSTORE_PASSWORD="${HTTPS_KEYSTORE_PASSWORD:-geoserver}"
    export HTTPS_KEYSTORE_PASSWORD

    mkdir -p "$(dirname "${HTTPS_KEYSTORE_FILE}")"
    keytool -genkey \
        -alias geoserver_self_signed \
        -keystore "${HTTPS_KEYSTORE_FILE}" \
        -deststoretype pkcs12 \
        -storepass "${HTTPS_KEYSTORE_PASSWORD}" \
        -keypass "${HTTPS_KEYSTORE_PASSWORD}" \
        -keyalg RSA \
        -keysize 2048 \
        -validity 365 \
        -dname "CN=localhost, OU=GeoServer, O=GeoServer, L=Unknown, ST=Unknown, C=US" \
        -noprompt

    echo "Self-signed keystore generated at [${HTTPS_KEYSTORE_FILE}] with password [${HTTPS_KEYSTORE_PASSWORD}]"
  fi

  java -jar $JETTY_HOME/start.jar --add-module=server,http,https,ssl,${DEPLOY_MODULES}
  echo "Installing Jetty with HTTPS support using substituted environment variables"
  envsubst < "/tmp/jetty/start.d/ssl.ini" > "${JETTY_BASE}/start.d/ssl.ini"
  envsubst < "/tmp/jetty/start.d/https.ini" > "${JETTY_BASE}/start.d/https.ini"
else
  cd $JETTY_BASE
  java -jar $JETTY_HOME/start.jar --add-module=server,http,${DEPLOY_MODULES}
fi

# RUN JETTY
cd $JETTY_BASE && java -jar /srv/jetty/start.jar