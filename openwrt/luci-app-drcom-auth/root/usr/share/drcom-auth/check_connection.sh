#!/bin/sh
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

CONFIG_FILE="$SCRIPT_DIR/config.sh"
if [ -f "$CONFIG_FILE" ]; then
	. "$CONFIG_FILE"
else
	echo "The config.sh is not found"
	exit 1
fi

if mkdir "$SCRIPT_DIR/auto_login_and_verify.lock" 2>/dev/null; then
	trap 'rmdir "$SCRIPT_DIR/auto_login_and_verify.lock"' EXIT INT TERM
	/bin/sh "$SCRIPT_DIR/auto_login_and_verify.sh"
else
	output_status "$STATUS_LOG_FILE" "auto_login_and_verify.sh is already running."
fi

output_status "$STATUS_LOG_FILE" "check_connection.sh completed successfully"
