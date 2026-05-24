#!/bin/sh
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

CONFIG_FILE="$SCRIPT_DIR/config.sh"
if [ -f "$CONFIG_FILE" ]; then
	. "$CONFIG_FILE"
else
	echo "The config.sh is not found"
	exit 1
fi

if pgrep -f "auto_login_and_verify.sh" >/dev/null; then
	output_status "$STATUS_LOG_FILE" "auto_login_and_verify.sh is already running."
else
	/bin/sh "$SCRIPT_DIR/auto_login_and_verify.sh"
fi

output_status "$STATUS_LOG_FILE" "check_connection.sh completed successfully"
