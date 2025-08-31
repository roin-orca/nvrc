#!/bin/bash
# watch-git-config-enhanced.sh

CONFIG_FILE="/home/ubuntu/actions-runner/_work/nvrc/nvrc/.git/config"
OUTPUT_FILE="git-config-changes.log"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: $CONFIG_FILE not found in current directory"
    exit 1
fi

{
    echo "Watching $CONFIG_FILE for changes..."
    echo "Started at: $(date)"
    echo "Process ID: $$"
    echo "Initial content:"
    echo "=================="
    cat "$CONFIG_FILE"
    echo "=================="
    echo "Initial checksum: $(md5sum "$CONFIG_FILE" | cut -d' ' -f1)"
    echo

    # Watch for ALL possible events that could affect the file
    inotifywait -m \
        -e modify \
        -e attrib \
        -e close_write \
        -e move \
        -e move_self \
        -e create \
        -e delete \
        -e delete_self \
        -e unmount \
        "$CONFIG_FILE" \
        --format '%T %e %f' \
        --timefmt '%Y-%m-%d %H:%M:%S.%N' |
    while read timestamp event file; do
        echo "[$timestamp] Event: $event on $file"
        
        # Calculate checksum to verify actual change
        if [ -f "$CONFIG_FILE" ]; then
            current_checksum=$(md5sum "$CONFIG_FILE" | cut -d' ' -f1)
            echo "Checksum: $current_checksum"
        else
            current_checksum="deleted"
            echo "Checksum: (file deleted)"
        fi
        
        echo "New content:"
        echo "----------"
        if [ -f "$CONFIG_FILE" ]; then
            cat "$CONFIG_FILE"
        else
            echo "(file deleted)"
        fi
        echo "----------"
        echo
    done
} > "$OUTPUT_FILE" 2>&1

echo "Logging to $OUTPUT_FILE (run 'tail -f $OUTPUT_FILE' to monitor)"
