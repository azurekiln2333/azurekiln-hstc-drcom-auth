#!/bin/sh
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

CONFIG_FILE="$SCRIPT_DIR/config.sh"
if [ -f "$CONFIG_FILE" ]; then
	. "$CONFIG_FILE"
else
	echo "The config.sh is not found"
	exit 1
fi

output_status "$STATUS_LOG_FILE" "Sending identity_login request: $AUTHORIZATION_API"
RESPONSE=$(curl -s -G "$AUTHORIZATION_API" \
	--data-urlencode "login_method=$LOGIN_METHOD" \
	--data-urlencode "wlan_user_ip=$TERM_IP" \
	--data-urlencode "wlan_user_ipv6=$TERM_IPV6" \
	--data-urlencode "wlan_user_mac=$TERM_MAC" \
	--data-urlencode "wlan_ac_ip=$WLAN_AC_IP" \
	--data-urlencode "wlan_ac_name=$WLAN_AC_NAME" \
	--data-urlencode "authex_enable=$AUTHEX_ENABLE" \
	--data-urlencode "mac_type=$MAC_TYPE" \
	--data-urlencode "jsVersion=$JS_VERSION")

output_status "$STATUS_LOG_FILE" "[response] $RESPONSE"
JSON=$(echo "$RESPONSE" | sed -e 's/^jsonpReturn(//' -e 's/);$//')
output_status "$STATUS_LOG_FILE" "[JSON] $JSON"

RESULT=$(echo "$JSON" | grep -o '"result"[ ]*:[ ]*[^,}]*' | cut -d ':' -f 2 | tr -d ' "')
output_status "$STATUS_LOG_FILE" "[RESULT] $RESULT"

if [ "$RESULT" = "1" ] || [ "$RESULT" = "ok" ]; then
	AUTHORIZE_URI=$(echo "$JSON" | sed -n 's/.*"authorize_uri"[ ]*:[ ]*"\([^"]*\)".*/\1/p')
	AUTHORIZE_URI=$(echo "$AUTHORIZE_URI" | sed 's#\\/#/#g')
	output_status "$STATUS_LOG_FILE" "Successfully obtained authorize URL: $AUTHORIZE_URI"
	printf "%s\n" "$AUTHORIZE_URI"
else
	MSG=$(echo "$RESPONSE" | grep -o '"msg"[ ]*:[ ]*"[^"]*"' | cut -d '"' -f 4)
	output_status "$STATUS_LOG_FILE" "Get authorize url failed: $MSG"
	printf "%s\n" "${MSG:-Get authorize url failed}" >&2
	exit 1
fi
