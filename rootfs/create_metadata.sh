#!/bin/bash
echo $ENTITY_ID

PROG="$(basename "$0")"

ENTITYID="$ENTITY_ID"
if [ -z "$ENTITYID" ]; then
    echo "$PROG: An entity ID is required." >&2
    exit 1
fi

BASEURL="$ENDPOINT_URL"
if [ -z "$BASEURL" ]; then
    echo "$PROG: The URL to the MellonEndpointPath is required." >&2
    exit 1
fi

echo $BASEURL
if ! echo "$BASEURL" | grep -q '^https\?://'; then
    echo "$PROG: The URL must start with \"http://\" or \"https://\"." >&2
    exit 1
fi

HOST="$(echo "$BASEURL" | sed 's#^[a-z]*://\([^/]*\).*#\1#')"
BASEURL="$(echo "$BASEURL" | sed 's#/$##')"

OUTFILE="wiki"
echo "Output files:"
echo "Private key:                              $OUTFILE.key"
echo "Certificate:                              $OUTFILE.cert"
echo "Metadata:                                 $OUTFILE.xml"
echo "Host:                                     $HOST"
echo
echo "Endpoints:"
echo "SingleLogoutService (SOAP):               $BASEURL/logout"
echo "SingleLogoutService (HTTP-Redirect):      $BASEURL/logout"
echo "AssertionConsumerService (HTTP-POST):     $BASEURL/postResponse"
echo "AssertionConsumerService (HTTP-Artifact): $BASEURL/artifactResponse"
echo "AssertionConsumerService (PAOS):          $BASEURL/paosResponse"
echo

# No files should not be readable by the rest of the world.
umask 0077

TEMPLATEFILE="$(mktemp -t mellon_create_sp.XXXXXXXXXX)"

cat >"$TEMPLATEFILE" <<EOF
RANDFILE           = /dev/urandom
[req]
default_bits       = 2048
default_keyfile    = privkey.pem
distinguished_name = req_distinguished_name
prompt             = no
policy             = policy_anything
[req_distinguished_name]
commonName         = $HOST
EOF

openssl req -utf8 -batch -config "$TEMPLATEFILE" -new -x509 -days 3652 -nodes -out "$OUTFILE.cert" -keyout "$OUTFILE.key" 2>/dev/null

rm -f "$TEMPLATEFILE"

CERT="$(grep -v '^-----' "$OUTFILE.cert")"

cat >"$OUTFILE.xml" <<EOF
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<EntityDescriptor
 entityID="$ENTITYID"
 xmlns="urn:oasis:names:tc:SAML:2.0:metadata">
 <SPSSODescriptor
   AuthnRequestsSigned="true"
   WantAssertionsSigned="true"
   protocolSupportEnumeration="urn:oasis:names:tc:SAML:2.0:protocol">
   <KeyDescriptor use="signing">
     <ds:KeyInfo xmlns:ds="http://www.w3.org/2000/09/xmldsig#">
       <ds:X509Data>
         <ds:X509Certificate>$CERT</ds:X509Certificate>
       </ds:X509Data>
     </ds:KeyInfo>
   </KeyDescriptor>
   <KeyDescriptor use="encryption">
     <ds:KeyInfo xmlns:ds="http://www.w3.org/2000/09/xmldsig#">
       <ds:X509Data>
         <ds:X509Certificate>$CERT</ds:X509Certificate>
       </ds:X509Data>
     </ds:KeyInfo>
   </KeyDescriptor>
   <SingleLogoutService
     Binding="urn:oasis:names:tc:SAML:2.0:bindings:SOAP"
     Location="$BASEURL/logout" />
   <SingleLogoutService
     Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect"
     Location="$BASEURL/logout" />
   <NameIDFormat>urn:oasis:names:tc:SAML:2.0:nameid-format:transient</NameIDFormat>
   <AssertionConsumerService
     index="0"
     isDefault="true"
     Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST"
     Location="$BASEURL/postResponse" />
   <AssertionConsumerService
     index="1"
     Binding="urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Artifact"
     Location="$BASEURL/artifactResponse" />
   <AssertionConsumerService
     index="2"
     Binding="urn:oasis:names:tc:SAML:2.0:bindings:PAOS"
     Location="$BASEURL/paosResponse" />
 </SPSSODescriptor>
</EntityDescriptor>
EOF

umask 0777
chmod go+r "$OUTFILE.xml"
chmod go+r "$OUTFILE.cert"
#cp "$OUTFILE.xml" /usr/local/apache2/
#cp "$OUTFILE.cert" /usr/local/apache2/
#cp "$OUTFILE.key" /usr/local/apache2/
curl https://login.microsoftonline.com/${AZURE_TENANT_NAME}/FederationMetadata/2007-06/FederationMetadata.xml -o /usr/local/apache2/azure.xml
chmod go+r /usr/local/apache2/azure.xml
chmod go+r /usr/local/apache2/wiki.*
echo -e "$EXTRA_HTTPD_CONF" >> /usr/local/apache2/conf/httpd.conf
cat /usr/local/apache2/conf/httpd.conf
httpd-foreground
