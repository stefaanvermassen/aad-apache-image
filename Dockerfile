FROM httpd:2.4
RUN apt-get update && apt-get install -y apt-file && apt-file update
RUN apt-get install -y libapache2-mod-auth-mellon unzip curl
RUN cp /usr/lib/apache2/modules/mod_auth_mellon.so /usr/local/apache2/modules/mod_auth_mellon.so
COPY rootfs /
ENV ENDPOINT_URL="test.com/mellon" \
    ENTITY_ID="test.com" \
    AZURE_TENANT_NAME="test.aad.com"
RUN chmod +x /create_metadata.sh
ENTRYPOINT [ "/create_metadata.sh" ]
