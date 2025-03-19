. ./.env

curl -k -X GET "https://$FQDN_IP/api/svm/svms" \
-H "accept: application/json" \
-H "Authorization: Basic $BASIC_AUTH"