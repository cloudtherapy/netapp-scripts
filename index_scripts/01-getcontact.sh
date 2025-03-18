. ./.env

curl -k --request GET \
--location "https://$FQDN_IP/api/cluster?fields=contact" \
--header "Authorization: Basic $BASIC_AUTH"