#!/bin/sh
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

CONFIG_FILE="$SCRIPT_DIR/config.sh"
if [ -f "$CONFIG_FILE" ]; then
	. "$CONFIG_FILE"
else
	echo "The config.sh is not found"
	exit 1
fi

if ! ping -c 1 "$PING_HOST" >/dev/null 2>&1; then
	output_status "$PING_LOG_FILE" "Network is down."
	if mkdir "$SCRIPT_DIR/check_connection.lock" 2>/dev/null; then
		trap 'rmdir "$SCRIPT_DIR/check_connection.lock"' EXIT INT TERM
		/bin/sh "$SCRIPT_DIR/check_connection.sh"
	else
		output_status "$PING_LOG_FILE" "check_connection.sh is already running."
	fi
else
	output_status "$PING_LOG_FILE" "Network is up."
fi
