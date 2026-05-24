#!/bin/sh
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

CONFIG_FILE="$SCRIPT_DIR/config.sh"
if [ -f "$CONFIG_FILE" ]; then
	. "$CONFIG_FILE"
else
	echo "The config file $CONFIG_FILE is not found."
	exit 1
fi

AUTHORIZE_URI="$1"
output_status "$LOG_FILE" "Received AUTHORIZE URI: $AUTHORIZE_URI"
output_status "$LOG_FILE" "Executing POST request to $HSCAS_LOGIN_URL"
POST_RESPONSE=$(curl -c "$COOKIE_FILE" -d "$LOGIN_POSTBODY" -X POST -s -o "$POST_RESPONSE_CONTENT" -w "%{http_code}" "$HSCAS_LOGIN_URL")

POST_SUCCESS=false
if grep -q "successRedirectUrl" "$POST_RESPONSE_CONTENT" || grep -q "登录成功" "$POST_RESPONSE_CONTENT" || grep -q "Log In Successful" "$POST_RESPONSE_CONTENT"; then
	POST_SUCCESS=true
fi

if [ "$POST_SUCCESS" = true ] && [ "$POST_RESPONSE" -eq 200 ]; then
	output_status "$STATUS_LOG_FILE" "Log In hstc Successful."
	output_status "$STATUS_LOG_FILE" "Executing GET request to $AUTHORIZE_URI to get ticket."

	curl -b "$COOKIE_FILE" -H "User-Agent: $USER_AGENT" -s -D "$HEADERS_FILE" -o "$GET_RESPONSE_CONTENT" "$AUTHORIZE_URI"
	GET_RESPONSE=$(awk 'NR == 1 { print $2 }' "$HEADERS_FILE")
	if [ "$GET_RESPONSE" -eq 302 ]; then
		LOCATION=$(grep -i "^Location:" "$HEADERS_FILE" | awk '{print $2}' | tr -d '\r')
		output_status "$STATUS_LOG_FILE" "Ticket obtained successfully: $LOCATION"
		output_status "$STATUS_LOG_FILE" "Verifying ticket..."
		THIRD_GET_RESPONSE=$(curl -b "$COOKIE_FILE" -H "User-Agent: $USER_AGENT" -s -o "$THIRD_GET_RESPONSE_CONTENT" -w "%{http_code}" "$LOCATION")
		if [ "$THIRD_GET_RESPONSE" -eq 302 ]; then
			output_status "$STATUS_LOG_FILE" "Ticket verification successful."
			exit 0
		else
			output_status "$STATUS_LOG_FILE" "Ticket verification failed."
			exit 3
		fi
	else
		output_status "$STATUS_LOG_FILE" "Failed to obtain ticket."
		exit 2
	fi
else
	output_status "$STATUS_LOG_FILE" "HSCAS login failed."
	exit 1
fi
