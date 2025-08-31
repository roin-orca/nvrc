#!/bin/bash
# watch-git-config.sh

CONFIG_FILE="/home/ubuntu/actions-runner/_work/nvrc/nvrc/.git/config"
OUTPUT_FILE="${1:-git-config-changes.log}"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: $CONFIG_FILE not found in current directory"
    exit 1
fi

echo "Watching $CONFIG_FILE for changes..."
echo "Logging to: $OUTPUT_FILE"

{
    echo "Git config watcher started at: $(date)"
    echo "Watching file: $CONFIG_FILE"
    echo "Host: $(hostname)"
    echo "Working directory: $(pwd)"
    echo "=========================================="
    echo "Initial content:"
    echo "=================="
    cat "$CONFIG_FILE"
    echo "=================="
    echo

    inotifywait -m -e modify,attrib,move,create,delete "$CONFIG_FILE" --format '%T %e %f' --timefmt '%Y-%m-%d %H:%M:%S' |
    while read timestamp event file; do
        echo "[$timestamp] Event: $event on $file"
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
} | tee "$OUTPUT_FILE"
