#!/data/data/com.termux/files/usr/bin/bash
# lib/monitor.sh - Monitoring daemon for Roblox instances
# Author: Roblox Manager Team
# Description: Background monitoring and auto-restart of crashed instances

# Shellcheck source
# shellcheck source=./utils.sh
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"
# shellcheck source=./clone-manager.sh
source "$(dirname "${BASH_SOURCE[0]}")/clone-manager.sh"
# shellcheck source=./freeform-manager.sh
source "$(dirname "${BASH_SOURCE[0]}")/freeform-manager.sh"

MONITOR_PID_FILE="${LOG_DIR}/monitor.pid"
MONITOR_LOG_FILE="${LOG_DIR}/monitor.log"

#######################################
# Check if monitor is running
# Returns:
#   0 if running, 1 otherwise
#######################################
is_monitor_running() {
    if [ ! -f "$MONITOR_PID_FILE" ]; then
        return 1
    fi
    
    local pid
    pid=$(cat "$MONITOR_PID_FILE" 2>/dev/null)
    
    if [ -z "$pid" ]; then
        return 1
    fi
    
    # Check if process exists
    if ps -p "$pid" >/dev/null 2>&1; then
        return 0
    else
        # Clean up stale PID file
        rm -f "$MONITOR_PID_FILE"
        return 1
    fi
}

#######################################
# Get monitor PID
# Returns:
#   PID or empty string
#######################################
get_monitor_pid() {
    if [ -f "$MONITOR_PID_FILE" ]; then
        cat "$MONITOR_PID_FILE" 2>/dev/null
    fi
}

#######################################
# Log to monitor log file
# Arguments:
#   $1 - Message
#######################################
monitor_log() {
    local message="$1"
    local timestamp
    timestamp=$(get_timestamp)
    
    echo "[$timestamp] $message" >> "$MONITOR_LOG_FILE"
}

#######################################
# Check instance health
# Arguments:
#   $1 - Instance ID
# Returns:
#   0 if healthy, 1 if crashed/stopped
#######################################
check_instance_health() {
    local instance_id="$1"
    
    local instance
    instance=$(get_instance "$instance_id")
    
    if [ -z "$instance" ] || [ "$instance" = "null" ]; then
        return 1
    fi
    
    local user_id
    user_id=$(echo "$instance" | jq -r '.user_id')
    
    local status
    status=$(echo "$instance" | jq -r '.status')
    
    # Skip if not supposed to be running
    if [ "$status" != "running" ]; then
        return 0
    fi
    
    local package
    package=$(get_config "roblox_package")
    
    # Check if process is actually running
    if adb_is_running "$package" "$user_id"; then
        return 0
    else
        # App crashed or was closed
        return 1
    fi
}

#######################################
# Restart instance
# Arguments:
#   $1 - Instance ID
#   $2 - Freeform bounds (optional)
# Returns:
#   0 on success
#######################################
restart_instance() {
    local instance_id="$1"
    local bounds="${2:-}"
    
    monitor_log "Restarting instance: $instance_id"
    
    local instance
    instance=$(get_instance "$instance_id")
    
    # Increment restart counter
    local restart_count
    restart_count=$(echo "$instance" | jq -r '.restart_count // 0')
    restart_count=$((restart_count + 1))
    
    update_instance "$instance_id" "restart_count" "$restart_count"
    
    # Check max restart attempts
    local max_attempts
    max_attempts=$(get_config "max_restart_attempts" "3")
    
    if [ "$restart_count" -gt "$max_attempts" ]; then
        monitor_log "Max restart attempts reached for $instance_id, giving up"
        update_instance "$instance_id" "status" "failed"
        return 1
    fi
    
    # Wait before restart (avoid crash loop)
    local restart_delay
    restart_delay=$(get_config "restart_delay" "5")
    sleep "$restart_delay"
    
    # Restart with or without freeform
    local freeform_enabled
    freeform_enabled=$(get_config "freeform_enabled" "true")
    
    if [ "$freeform_enabled" = "true" ] && [ -n "$bounds" ]; then
        launch_freeform "$instance_id" "$bounds"
    else
        start_clone "$instance_id"
    fi
    
    local result=$?
    
    if [ $result -eq 0 ]; then
        monitor_log "Successfully restarted $instance_id (attempt $restart_count)"
        # Reset restart counter on success
        update_instance "$instance_id" "restart_count" "0"
        return 0
    else
        monitor_log "Failed to restart $instance_id (attempt $restart_count)"
        return 1
    fi
}

#######################################
# Monitor loop (main monitoring function)
# Arguments:
#   None
# Returns:
#   Never returns (daemon loop)
#######################################
monitor_loop() {
    monitor_log "Monitor daemon started (PID: $$)"
    
    local check_interval
    check_interval=$(get_config "monitoring_interval" "30")
    
    local auto_restart
    auto_restart=$(get_config "auto_restart" "true")
    
    # Store window positions for freeform restart
    declare -A instance_bounds
    
    while true; do
        # Check ADB connection
        if ! adb_is_connected; then
            monitor_log "WARNING: ADB not connected, waiting..."
            sleep "$check_interval"
            continue
        fi
        
        # Get all instances
        local instances
        instances=$(get_all_instances | jq -r '.[] | @base64')
        
        for instance_b64 in $instances; do
            local instance
            instance=$(echo "$instance_b64" | base64 -d)
            
            local instance_id
            instance_id=$(echo "$instance" | jq -r '.id')
            
            local status
            status=$(echo "$instance" | jq -r '.status')
            
            # Only monitor running instances
            if [ "$status" != "running" ]; then
                continue
            fi
            
            # Check health
            if ! check_instance_health "$instance_id"; then
                monitor_log "Detected crashed/stopped instance: $instance_id"
                
                if [ "$auto_restart" = "true" ]; then
                    # Get stored bounds if available
                    local bounds="${instance_bounds[$instance_id]:-}"
                    
                    # If no stored bounds, calculate new ones
                    if [ -z "$bounds" ]; then
                        # Simple default position
                        bounds="100,100,800,600"
                    fi
                    
                    restart_instance "$instance_id" "$bounds"
                else
                    monitor_log "Auto-restart disabled, marking as stopped"
                    update_instance "$instance_id" "status" "stopped"
                fi
            fi
        done
        
        # Sleep before next check
        sleep "$check_interval"
    done
}

#######################################
# Start monitor daemon
# Arguments:
#   None
# Returns:
#   0 on success
#######################################
start_monitor() {
    if is_monitor_running; then
        local pid
        pid=$(get_monitor_pid)
        log_warn "Monitor already running (PID: $pid)"
        return 1
    fi
    
    log_info "Starting monitor daemon..."
    
    # Check dependencies
    if ! adb_is_connected; then
        log_warn "ADB not connected. Monitor will wait for connection."
    fi
    
    # Start monitor in background
    nohup bash -c "source '$SCRIPT_DIR/lib/monitor.sh' && monitor_loop" > "$MONITOR_LOG_FILE" 2>&1 &
    
    local pid=$!
    echo "$pid" > "$MONITOR_PID_FILE"
    
    # Verify it started
    sleep 1
    if is_monitor_running; then
        log_success "Monitor daemon started (PID: $pid)"
        log_info "Monitor log: $MONITOR_LOG_FILE"
        return 0
    else
        log_error "Failed to start monitor daemon"
        rm -f "$MONITOR_PID_FILE"
        return 1
    fi
}

#######################################
# Stop monitor daemon
# Arguments:
#   None
# Returns:
#   0 on success
#######################################
stop_monitor() {
    if ! is_monitor_running; then
        log_warn "Monitor not running"
        return 1
    fi
    
    local pid
    pid=$(get_monitor_pid)
    
    log_info "Stopping monitor daemon (PID: $pid)..."
    
    # Send TERM signal
    kill "$pid" 2>/dev/null
    
    # Wait for process to stop
    local timeout=10
    local elapsed=0
    
    while ps -p "$pid" >/dev/null 2>&1; do
        sleep 1
        ((elapsed++))
        
        if [ $elapsed -ge $timeout ]; then
            log_warn "Monitor didn't stop gracefully, forcing..."
            kill -9 "$pid" 2>/dev/null
            break
        fi
    done
    
    # Clean up PID file
    rm -f "$MONITOR_PID_FILE"
    
    log_success "Monitor daemon stopped"
    
    monitor_log "Monitor daemon stopped"
}

#######################################
# Restart monitor daemon
# Arguments:
#   None
# Returns:
#   0 on success
#######################################
restart_monitor() {
    log_info "Restarting monitor daemon..."
    
    if is_monitor_running; then
        stop_monitor
        sleep 2
    fi
    
    start_monitor
}

#######################################
# Get monitor status
# Arguments:
#   None
# Returns:
#   Status info
#######################################
monitor_status() {
    echo -e "${CYAN}=== Monitor Status ===${NC}"
    echo ""
    
    if is_monitor_running; then
        local pid
        pid=$(get_monitor_pid)
        echo -e "${GREEN}✓${NC} Status: ${GREEN}Running${NC}"
        echo -e "${BLUE}PID:${NC} $pid"
        
        # Show uptime
        local start_time
        if [ -f "$MONITOR_PID_FILE" ]; then
            start_time=$(stat -c %Y "$MONITOR_PID_FILE" 2>/dev/null || stat -f %m "$MONITOR_PID_FILE" 2>/dev/null)
            local current_time
            current_time=$(date +%s)
            local uptime=$((current_time - start_time))
            echo -e "${BLUE}Uptime:${NC} $(format_duration "$uptime")"
        fi
    else
        echo -e "${RED}✗${NC} Status: ${RED}Not Running${NC}"
        echo ""
        echo "Start with: roblox-manager.sh monitor start"
        return 1
    fi
    
    echo -e "${BLUE}Check interval:${NC} $(get_config 'monitoring_interval' '30')s"
    echo -e "${BLUE}Auto-restart:${NC} $(get_config 'auto_restart' 'true')"
    echo -e "${BLUE}Max restart attempts:${NC} $(get_config 'max_restart_attempts' '3')"
    
    # Show log tail
    if [ -f "$MONITOR_LOG_FILE" ]; then
        echo ""
        echo -e "${CYAN}Recent log entries:${NC}"
        tail -n 5 "$MONITOR_LOG_FILE" 2>/dev/null | while read -r line; do
            echo "  $line"
        done
    fi
    
    echo ""
}

#######################################
# View monitor logs
# Arguments:
#   $1 - Number of lines (default: 20)
# Returns:
#   Log contents
#######################################
view_monitor_logs() {
    local lines="${1:-20}"
    
    if [ ! -f "$MONITOR_LOG_FILE" ]; then
        log_warn "No monitor logs found"
        return 1
    fi
    
    echo -e "${CYAN}=== Monitor Logs (last $lines lines) ===${NC}"
    echo ""
    
    tail -n "$lines" "$MONITOR_LOG_FILE"
}

#######################################
# Clear monitor logs
# Arguments:
#   None
# Returns:
#   0 on success
#######################################
clear_monitor_logs() {
    if [ -f "$MONITOR_LOG_FILE" ]; then
        > "$MONITOR_LOG_FILE"
        log_success "Monitor logs cleared"
    else
        log_warn "No monitor logs to clear"
    fi
}
