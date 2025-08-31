#!/bin/bash
# git-config-dump.sh

OUTPUT_FILE="git-config-dump.log"
INTERVAL=0.5  # seconds

echo "Dumping git config --list every ${INTERVAL}s to $OUTPUT_FILE"
echo "Press Ctrl+C to stop"

while true; do
    {
        echo "=== $(date '+%Y-%m-%d %H:%M:%S.%N') ==="
        git config --list 2>/dev/null || echo "ERROR: Failed to get git config"
        echo
    } >> "$OUTPUT_FILE"
    
    sleep "$INTERVAL"
done
