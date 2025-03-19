. ./.env

curl -k -X GET "https://$FQDN_IP/api/cluster" \
-H "accept: application/json" \
-H "Authorization: Basic $BASIC_AUTH"