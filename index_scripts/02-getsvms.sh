. ./.env

curl -k -X GET "https://$FQDN_IP/api/svm/svms?return_records=true&return_timeout=15" \
-H "accept: application/json" \
-H "Authorization: Basic $BASIC_AUTH"