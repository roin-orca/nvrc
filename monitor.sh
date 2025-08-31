#!/bin/bash

# Git Process Monitor Script
# Monitors for git clone processes and logs their full command lines

# Configuration
LOG_FILE="${HOME}/git_monitor.log"
POLL_INTERVAL=0.5  # Check every 0.5 seconds
PID_FILE="/tmp/git_monitor.pid"
SEEN_PIDS_FILE="/tmp/git_monitor_pids.tmp"

# Function to log messages with timestamp
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Function to cleanup on exit
cleanup() {
    log_message "Git monitor stopped (PID: $$)"
    rm -f "$PID_FILE" "$SEEN_PIDS_FILE"
    exit 0
}

# Function to check if script is already running
check_running() {
    if [[ -f "$PID_FILE" ]]; then
        local existing_pid=$(cat "$PID_FILE")
        if kill -0 "$existing_pid" 2>/dev/null; then
            echo "Git monitor is already running with PID: $existing_pid"
            echo "Log file: $LOG_FILE"
            exit 1
        else
            rm -f "$PID_FILE" "$SEEN_PIDS_FILE"
        fi
    fi
}

# Function to get git processes - try different ps formats
get_git_processes() {
    # Try different ps command formats depending on the system
    if ps -eo pid,args >/dev/null 2>&1; then
        # Linux/GNU ps
        ps -eo pid,args | grep -E "git\s+" | grep -v grep | grep -v "$0"
    elif ps -axo pid,command >/dev/null 2>&1; then
        # BSD/macOS ps
        ps -axo pid,command | grep -E "git\s+" | grep -v grep | grep -v "$0"
    elif ps -ef >/dev/null 2>&1; then
        # POSIX ps - extract PID and command
        ps -ef | grep -E "git\s+" | grep -v grep | grep -v "$0" | awk '{pid=$2; $1=$2=$3=$4=$5=""; print pid, $0}' | sed 's/^[^ ]* *//'
    else
        # Fallback to basic ps
        ps aux | grep -E "git\s+" | grep -v grep | grep -v "$0" | awk '{pid=$2; for(i=11;i<=NF;i++) cmd=cmd" "$i; print pid, cmd; cmd=""}'
    fi
}

# Function to check if PID has been seen
pid_seen() {
    local pid="$1"
    if [[ -f "$SEEN_PIDS_FILE" ]]; then
        grep -q "^${pid}$" "$SEEN_PIDS_FILE" 2>/dev/null
    else
        return 1
    fi
}

# Function to mark PID as seen
mark_pid_seen() {
    local pid="$1"
    echo "$pid" >> "$SEEN_PIDS_FILE"
}

# Function to clean up dead PIDs from tracking file
cleanup_dead_pids() {
    if [[ -f "$SEEN_PIDS_FILE" ]]; then
        local temp_file=$(mktemp)
        while IFS= read -r pid; do
            if kill -0 "$pid" 2>/dev/null; then
                echo "$pid" >> "$temp_file"
            fi
        done < "$SEEN_PIDS_FILE"
        mv "$temp_file" "$SEEN_PIDS_FILE"
    fi
}

# Function to start monitoring
start_monitor() {
    # Store our PID
    echo $$ > "$PID_FILE"
    
    # Initialize seen PIDs file
    > "$SEEN_PIDS_FILE"
    
    log_message "Git monitor started (PID: $$)"
    log_message "Monitoring for git processes, logging to: $LOG_FILE"
    
    local cleanup_counter=0
    
    while true; do
        # Find all git processes
        while IFS= read -r line; do
            if [[ -n "$line" ]]; then
                # Extract PID (first field) and command (rest)
                local pid=$(echo "$line" | awk '{print $1}')
                local cmd=$(echo "$line" | cut -d' ' -f2-)
                
                # Skip if we've already logged this PID
                if ! pid_seen "$pid"; then
                    mark_pid_seen "$pid"
                    
                    # Log the git command
                    if [[ "$cmd" == *"git clone"* ]]; then
                        log_message "GIT CLONE DETECTED - PID: $pid, Command: $cmd"
                    else
                        log_message "GIT PROCESS - PID: $pid, Command: $cmd"
                    fi
                fi
            fi
        done < <(get_git_processes)
        
        # Clean up dead PIDs periodically (every 20 iterations)
        cleanup_counter=$((cleanup_counter + 1))
        if [[ $cleanup_counter -ge 20 ]]; then
            cleanup_dead_pids
            cleanup_counter=0
        fi
        
        sleep "$POLL_INTERVAL"
    done
}

# Function to stop the monitor
stop_monitor() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            echo "Git monitor stopped (PID: $pid)"
            rm -f "$SEEN_PIDS_FILE"
        else
            echo "Git monitor was not running"
            rm -f "$PID_FILE" "$SEEN_PIDS_FILE"
        fi
    else
        echo "Git monitor is not running"
    fi
}

# Function to show status
show_status() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo "Git monitor is running (PID: $pid)"
            echo "Log file: $LOG_FILE"
            if [[ -f "$LOG_FILE" ]]; then
                local size=$(ls -lh "$LOG_FILE" 2>/dev/null | awk '{print $5}' || echo "unknown")
                echo "Log file size: $size"
                echo "Latest entries:"
                tail -5 "$LOG_FILE" 2>/dev/null
            fi
            if [[ -f "$SEEN_PIDS_FILE" ]]; then
                local tracked_pids=$(wc -l < "$SEEN_PIDS_FILE" 2>/dev/null || echo "0")
                echo "Currently tracking: $tracked_pids PIDs"
            fi
        else
            echo "Git monitor is not running (stale PID file)"
            rm -f "$PID_FILE" "$SEEN_PIDS_FILE"
        fi
    else
        echo "Git monitor is not running"
    fi
}

# Function to show the log
show_log() {
    if [[ -f "$LOG_FILE" ]]; then
        if [[ "$1" == "-f" ]]; then
            tail -f "$LOG_FILE"
        else
            cat "$LOG_FILE"
        fi
    else
        echo "Log file does not exist: $LOG_FILE"
    fi
}

# Set up signal handlers
trap cleanup SIGTERM SIGINT

# Main script logic
case "${1:-start}" in
    start)
        check_running
        echo "Starting git monitor..."
        echo "Log file: $LOG_FILE"
        echo "PID file: $PID_FILE"
        echo "Use '$0 stop' to stop monitoring"
        echo "Use '$0 status' to check status"
        echo "Use '$0 log' to view the log"
        start_monitor
        ;;
    stop)
        stop_monitor
        ;;
    restart)
        stop_monitor
        sleep 1
        check_running
        start_monitor
        ;;
    status)
        show_status
        ;;
    log)
        show_log
        ;;
    tail)
        show_log -f
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|log|tail}"
        echo ""
        echo "Commands:"
        echo "  start   - Start monitoring git processes"
        echo "  stop    - Stop the monitor"
        echo "  restart - Restart the monitor"
        echo "  status  - Show monitor status"
        echo "  log     - Show the full log"
        echo "  tail    - Follow the log in real-time"
        exit 1
        ;;
esac
