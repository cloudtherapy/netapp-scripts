. ./.env

curl --request GET \
--location "https://$FQDN_IP/api/cluster?fields=contact" \
--insecure \
--include \
--header "Authorization: Basic $BASIC_AUTH"