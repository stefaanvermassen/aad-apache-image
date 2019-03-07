FROM httpd:2.4
RUN apt-get update && apt-get install -y apt-file && apt-file update
RUN apt-get install -y libapache2-mod-auth-mellon unzip
COPY rootfs /
ENV ENDPOINT_URL="test.com/mellon" \
    ENTITY_ID="test.com" \
    AZURE_TENANT_NAME="test.aad.com"
    
ENTRYPOINT [ "/create_metadata.sh" ]
