#!/bin/sh
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

CONFIG_FILE="$SCRIPT_DIR/config.sh"
if [ -f "$CONFIG_FILE" ]; then
	. "$CONFIG_FILE"
else
	echo "The config.sh is not found"
	exit 1
fi

AUTHORIZE_URI=$(/bin/sh "$SCRIPT_DIR/get_authorize_url.sh")
if [ -n "$AUTHORIZE_URI" ]; then
	output_status "$STATUS_LOG_FILE" "Attempting to login to HSCAS..."
	/bin/sh "$SCRIPT_DIR/hscas_login.sh" "$AUTHORIZE_URI"
else
	output_status "$STATUS_LOG_FILE" "Get authorize url failed"
	exit 1
fi
