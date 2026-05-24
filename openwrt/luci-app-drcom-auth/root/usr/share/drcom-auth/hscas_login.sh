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
output_status "$LOG_FILE" "Loading HSCAS login page to fetch execution token"
LOGIN_PAGE_RESPONSE=$(curl -L -c "$COOKIE_FILE" -b "$COOKIE_FILE" -H "User-Agent: $USER_AGENT" -s -o "$LOGIN_PAGE_CONTENT" -w "%{http_code}" "$AUTHORIZE_URI")
EXECUTION=$(sed -n 's/.*name="execution" value="\([^"]*\)".*/\1/p' "$LOGIN_PAGE_CONTENT" | head -n 1)
if [ -z "$EXECUTION" ]; then
	output_status "$STATUS_LOG_FILE" "HSCAS login failed: execution token not found, HTTP $LOGIN_PAGE_RESPONSE"
	exit 1
fi
CURRENT_MENU=$(sed -n 's/.*name="currentMenu" value="\([^"]*\)".*/\1/p' "$LOGIN_PAGE_CONTENT" | head -n 1)
FAIL_N=$(sed -n 's/.*name="failN" value="\([^"]*\)".*/\1/p' "$LOGIN_PAGE_CONTENT" | head -n 1)
CURRENT_MENU=${CURRENT_MENU:-1}
FAIL_N=${FAIL_N:-0}

if [ ! -s "$PUBLIC_KEY_FILE" ] && [ -s "$DEFAULT_PUBLIC_KEY_FILE" ]; then
	cp "$DEFAULT_PUBLIC_KEY_FILE" "$PUBLIC_KEY_FILE"
	chmod 600 "$PUBLIC_KEY_FILE"
fi

if [ ! -s "$PUBLIC_KEY_FILE" ]; then
	output_status "$LOG_FILE" "Fetching HSCAS RSA public key"
	if ! curl -L -b "$COOKIE_FILE" -H "User-Agent: $USER_AGENT" -s -o "$PUBLIC_KEY_FILE" "$HSCAS_PUBLIC_KEY_URL"; then
		output_status "$STATUS_LOG_FILE" "HSCAS login failed: public key request failed"
		exit 1
	fi
fi

if ! grep -q "BEGIN PUBLIC KEY" "$PUBLIC_KEY_FILE"; then
	output_status "$STATUS_LOG_FILE" "HSCAS login failed: invalid public key"
	exit 1
fi

encrypt_password() {
	local encrypted
	if encrypted=$(printf "%s" "$PASSWORD" | openssl pkeyutl -encrypt -pubin -inkey "$PUBLIC_KEY_FILE" -pkeyopt rsa_padding_mode:pkcs1 2>/dev/null | base64 | tr -d '\r\n'); then
		printf "%s\n" "__RSA__$encrypted"
		return 0
	fi

	if encrypted=$(printf "%s" "$PASSWORD" | openssl rsautl -encrypt -pubin -inkey "$PUBLIC_KEY_FILE" -pkcs 2>/dev/null | base64 | tr -d '\r\n'); then
		printf "%s\n" "__RSA__$encrypted"
		return 0
	fi

	return 1
}

ENCRYPTED_PASSWORD=$(encrypt_password)
if [ -z "$ENCRYPTED_PASSWORD" ]; then
	output_status "$STATUS_LOG_FILE" "HSCAS login failed: password encryption failed, openssl is required"
	exit 1
fi

output_status "$LOG_FILE" "Executing POST request to $AUTHORIZE_URI"
POST_RESPONSE=$(curl -c "$COOKIE_FILE" -b "$COOKIE_FILE" -H "User-Agent: $USER_AGENT" -X POST -s -D "$HEADERS_FILE" -o "$POST_RESPONSE_CONTENT" -w "%{http_code}" \
	--data-urlencode "username=$USERNAME" \
	--data-urlencode "password=$ENCRYPTED_PASSWORD" \
	--data-urlencode "currentMenu=$CURRENT_MENU" \
	--data-urlencode "failN=$FAIL_N" \
	--data-urlencode "execution=$EXECUTION" \
	--data-urlencode "_eventId=submit" \
	--data-urlencode "geolocation=" \
	--data-urlencode "submit=登录" \
	"$AUTHORIZE_URI")

POST_SUCCESS=false
if grep -q "successRedirectUrl" "$POST_RESPONSE_CONTENT" || grep -q "登录成功" "$POST_RESPONSE_CONTENT" || grep -q "Log In Successful" "$POST_RESPONSE_CONTENT"; then
	POST_SUCCESS=true
fi

if [ "$POST_RESPONSE" -eq 302 ]; then
	output_status "$STATUS_LOG_FILE" "Log In hstc Successful."
	LOCATION=$(grep -i "^Location:" "$HEADERS_FILE" | awk '{print $2}' | tr -d '\r')
	if [ -n "$LOCATION" ]; then
		output_status "$STATUS_LOG_FILE" "Ticket obtained successfully: $LOCATION"
		output_status "$STATUS_LOG_FILE" "Verifying ticket..."
		THIRD_GET_RESPONSE=$(curl -b "$COOKIE_FILE" -H "User-Agent: $USER_AGENT" -s -o "$THIRD_GET_RESPONSE_CONTENT" -w "%{http_code}" "$LOCATION")
		if [ "$THIRD_GET_RESPONSE" -eq 302 ]; then
			output_status "$STATUS_LOG_FILE" "Ticket verification successful."
			exit 0
		fi
	fi

	output_status "$STATUS_LOG_FILE" "Ticket verification failed."
	exit 3
elif [ "$POST_SUCCESS" = true ] && [ "$POST_RESPONSE" -eq 200 ]; then
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
