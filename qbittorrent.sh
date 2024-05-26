#!/bin/bash

#######
## TO Add this to qbittorrent GO TO WEB UI AND EDIT IT MANUALLY AND PASTE LOCAL IP IN SONARR/RADARR.

## TODO: LOAD TORRENT LIST AND SEND UNQUIE ONE ONLY.
## TODO: EVERY 2 WEEKS RE-INSERT ALL TORRENTS JUST IN CASE.
#######

## Login to qBittorrent and get the cookie value
## DO NOT FORGET TO REPLACE username= and password= with your username and password of web ui. username=admin&password=adminadmin
## by default port is 8080 but change it if needed.
curl_output=$(curl -i --header 'Referer: http://localhost:8080' --data 'username=admin&password=adminadmin' http://localhost:8080/api/v2/auth/login)
set_cookie_header=$(echo "$curl_output" | grep -i 'Set-Cookie' | tr -d '[:space:]' | sed 's/set-cookie://i')
cookie_value=$(echo "$set_cookie_header" | cut -d ';' -f 1 | tr -d ';')

## Retrieve torrents info
json_output=$(curl -s "http://localhost:8080/api/v2/torrents/info" --cookie "$cookie_value")

## Check if there was an error with the curl request
if [ -z "$json_output" ]; then
    echo "Error: Unable to retrieve torrents info."
    exit 1
fi

### TO UPLOAD TO DEBRID LINK

## Get yours: https://debrid-link.com/webapp/apikey
API_KEY=""

## Loop through megnet links and upload them to debrid-link
echo "$json_output" | jq -r '.[] | .name, .magnet_uri' | while IFS= read -r name && IFS= read -r magnet_uri; do
    FILE_URL="$magnet_uri"

    ## Make an HTTP POST request to the seedbox-add endpoint
    curl_output=$(curl -s -X POST "https://debrid-link.com/api/v2/seedbox/add" \
        -H "Authorization: Bearer $API_KEY" \
        -d "url=$FILE_URL")

    ## Checks for errors like torrent is too big and if so adds it to failed_torrents.txt file.
    if echo "$curl_output" | jq -e '.success == false' >/dev/null; then
        error=$(echo "$curl_output" | jq -r '.error')
        error_id=$(echo "$curl_output" | jq -r '.error_id')
        echo "$name : $magnet_uri - ($error - $error_id)"  >> failed_torrents.txt
        echo "" >> failed_torrents.txt
    else
        # Process the response normally
        echo "Successfully added: $name"
    fi
done
