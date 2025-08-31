#!/bin/bash
# watch-git-config.sh

CONFIG_FILE=".git/config"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: $CONFIG_FILE not found in current directory"
    exit 1
fi

echo "Watching $CONFIG_FILE for changes..."
echo "Initial content:"
echo "=================="
cat "$CONFIG_FILE"
echo "=================="
echo

# Install inotify-tools if not available:
# Ubuntu/Debian: sudo apt-get install inotify-tools
# macOS: brew install fswatch (use fswatch version below instead)

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
