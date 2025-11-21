#!/data/data/com.termux/files/usr/bin/bash
# lib/freeform-manager.sh - Freeform window management
# Author: Roblox Manager Team
# Description: Manage freeform windows for multiple Roblox instances

# Shellcheck source
# shellcheck source=./utils.sh
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"
# shellcheck source=./clone-manager.sh
source "$(dirname "${BASH_SOURCE[0]}")/clone-manager.sh"

#######################################
# Check if freeform is supported
# Returns:
#   0 if supported, 1 otherwise
#######################################
is_freeform_supported() {
    local freeform_status
    freeform_status=$(adb_shell "settings get global enable_freeform_support" 2>/dev/null)
    
    if [ "$freeform_status" = "1" ]; then
        return 0
    fi
    
    # Check via dumpsys
    if adb_shell "dumpsys window | grep -i freeform" | grep -q "freeform"; then
        return 0
    fi
    
    return 1
}

#######################################
# Enable freeform mode
# Returns:
#   0 on success
#######################################
enable_freeform() {
    log_info "Enabling freeform mode..."
    
    if ! adb_is_connected; then
        log_error "ADB not connected"
        return 1
    fi
    
    # Enable freeform support
    adb_shell "settings put global enable_freeform_support 1" 2>/dev/null
    adb_shell "settings put global force_resizable_activities 1" 2>/dev/null
    
    sleep 1
    
    if is_freeform_supported; then
        log_success "Freeform mode enabled"
        return 0
    else
        log_warn "Freeform may not be fully supported on this device"
        return 1
    fi
}

#######################################
# Disable freeform mode
# Returns:
#   0 on success
#######################################
disable_freeform() {
    log_info "Disabling freeform mode..."
    
    adb_shell "settings put global enable_freeform_support 0" 2>/dev/null
    
    log_success "Freeform mode disabled"
}

#######################################
# Get screen resolution
# Returns:
#   "WIDTHxHEIGHT"
#######################################
get_screen_resolution() {
    local resolution
    resolution=$(adb_shell "wm size" | grep "Physical size" | cut -d: -f2 | tr -d ' \r\n')
    
    if [ -z "$resolution" ]; then
        # Fallback
        resolution="1920x1080"
    fi
    
    echo "$resolution"
}

#######################################
# Calculate window positions for grid layout
# Arguments:
#   $1 - Number of windows
# Returns:
#   Array of "X,Y,WIDTH,HEIGHT" positions
#######################################
calculate_grid_positions() {
    local count="$1"
    
    # Get screen resolution
    local resolution
    resolution=$(get_screen_resolution)
    
    local screen_width
    screen_width=$(echo "$resolution" | cut -d'x' -f1)
    
    local screen_height
    screen_height=$(echo "$resolution" | cut -d'x' -f2)
    
    # Calculate grid dimensions
    local cols
    local rows
    
    case $count in
        1)
            cols=1
            rows=1
            ;;
        2)
            cols=2
            rows=1
            ;;
        3|4)
            cols=2
            rows=2
            ;;
        5|6)
            cols=3
            rows=2
            ;;
        *)
            cols=3
            rows=$(( (count + 2) / 3 ))
            ;;
    esac
    
    # Calculate window dimensions with padding
    local padding=20
    local window_width=$(( (screen_width - (cols + 1) * padding) / cols ))
    local window_height=$(( (screen_height - (rows + 1) * padding) / rows ))
    
    # Generate positions
    local positions=()
    local idx=0
    
    for ((row=0; row<rows && idx<count; row++)); do
        for ((col=0; col<cols && idx<count; col++)); do
            local x=$(( padding + col * (window_width + padding) ))
            local y=$(( padding + row * (window_height + padding) ))
            
            positions+=("${x},${y},${window_width},${window_height}")
            ((idx++))
        done
    done
    
    printf '%s\n' "${positions[@]}"
}

#######################################
# Launch app in freeform mode
# Arguments:
#   $1 - Instance ID
#   $2 - Window bounds (X,Y,WIDTH,HEIGHT)
# Returns:
#   0 on success
#######################################
launch_freeform() {
    local instance_id="$1"
    local bounds="$2"
    
    if ! adb_is_connected; then
        log_error "ADB not connected"
        return 1
    fi
    
    local instance
    instance=$(get_instance "$instance_id")
    
    if [ -z "$instance" ] || [ "$instance" = "null" ]; then
        log_error "Instance not found: $instance_id"
        return 1
    fi
    
    local user_id
    user_id=$(echo "$instance" | jq -r '.user_id')
    
    local package
    package=$(get_config "roblox_package")
    
    # Parse bounds
    IFS=',' read -r x y width height <<< "$bounds"
    
    local stack_bounds="${x},${y},$((x + width)),$((y + height))"
    
    log_info "Launching $instance_id in freeform at $stack_bounds..."
    
    # Launch in freeform mode with specific bounds
    adb_shell "am start --user $user_id -n ${package}/com.roblox.client.startup.ActivitySplash --activity-single-top --windowingMode 5 --activityType 1 --bounds $stack_bounds" >/dev/null 2>&1
    
    sleep 2
    
    # Verify app started
    if adb_is_running "$package" "$user_id"; then
        log_success "$instance_id launched in freeform"
        
        # Update instance status
        update_instance "$instance_id" "status" "running"
        
        local pid
        pid=$(adb_shell "pidof -s $package" 2>/dev/null | tr -d '\r\n')
        if [ -n "$pid" ]; then
            update_instance "$instance_id" "pid" "$pid"
        fi
        
        return 0
    else
        log_error "Failed to launch $instance_id"
        return 1
    fi
}

#######################################
# Launch multiple instances in freeform
# Arguments:
#   $@ - Instance IDs
# Returns:
#   0 on success
#######################################
launch_all_freeform() {
    local instance_ids=("$@")
    local count=${#instance_ids[@]}
    
    if [ $count -eq 0 ]; then
        log_error "No instances specified"
        return 1
    fi
    
    # Enable freeform if not already
    if ! is_freeform_supported; then
        enable_freeform
    fi
    
    log_info "Launching $count instances in freeform mode..."
    
    # Get layout
    local layout
    layout=$(get_config "freeform_layout" "grid")
    
    # Calculate positions
    local positions
    mapfile -t positions < <(calculate_grid_positions "$count")
    
    # Launch each instance
    local success=0
    local idx=0
    
    for instance_id in "${instance_ids[@]}"; do
        local bounds="${positions[$idx]}"
        
        if launch_freeform "$instance_id" "$bounds"; then
            ((success++))
        fi
        
        ((idx++))
        
        # Small delay between launches
        sleep 1
    done
    
    log_success "Launched $success/$count instances in freeform mode"
    
    [ $success -eq $count ]
}

#######################################
# Launch all configured instances in freeform
# Arguments:
#   None
# Returns:
#   0 on success
#######################################
launch_all_instances_freeform() {
    local instances
    instances=$(get_all_instances | jq -r '.[].id')
    
    if [ -z "$instances" ]; then
        log_error "No instances found"
        return 1
    fi
    
    local instance_ids
    mapfile -t instance_ids <<< "$instances"
    
    launch_all_freeform "${instance_ids[@]}"
}

#######################################
# Resize freeform window
# Arguments:
#   $1 - Instance ID
#   $2 - New bounds (X,Y,WIDTH,HEIGHT)
# Returns:
#   0 on success
#######################################
resize_freeform_window() {
    local instance_id="$1"
    local bounds="$2"
    
    # Parse bounds
    IFS=',' read -r x y width height <<< "$bounds"
    local stack_bounds="${x},${y},$((x + width)),$((y + height))"
    
    log_info "Resizing $instance_id window to $stack_bounds..."
    
    # Get task ID for the app
    local package
    package=$(get_config "roblox_package")
    
    local instance
    instance=$(get_instance "$instance_id")
    local user_id
    user_id=$(echo "$instance" | jq -r '.user_id')
    
    # Get task ID
    local task_id
    task_id=$(adb_shell "dumpsys activity activities | grep -A 20 'u${user_id}.*${package}' | grep 'Task id' | head -n1" | sed -n 's/.*Task id #\([0-9]*\).*/\1/p')
    
    if [ -n "$task_id" ]; then
        adb_shell "am task resize $task_id $stack_bounds" 2>/dev/null
        log_success "Window resized"
        return 0
    else
        log_error "Could not find task ID for $instance_id"
        return 1
    fi
}

#######################################
# Rearrange all freeform windows
# Arguments:
#   None
# Returns:
#   0 on success
#######################################
rearrange_freeform_windows() {
    log_info "Rearranging freeform windows..."
    
    # Get running instances
    local running_instances
    running_instances=$(get_all_instances | jq -r '.[] | select(.status == "running") | .id')
    
    if [ -z "$running_instances" ]; then
        log_warn "No running instances to arrange"
        return 0
    fi
    
    local instance_ids
    mapfile -t instance_ids <<< "$running_instances"
    
    local count=${#instance_ids[@]}
    
    # Calculate new positions
    local positions
    mapfile -t positions < <(calculate_grid_positions "$count")
    
    # Resize each window
    local idx=0
    for instance_id in "${instance_ids[@]}"; do
        local bounds="${positions[$idx]}"
        resize_freeform_window "$instance_id" "$bounds" 2>/dev/null || true
        ((idx++))
    done
    
    log_success "Windows rearranged"
}

#######################################
# Check freeform status
# Arguments:
#   None
# Returns:
#   Status message
#######################################
check_freeform_status() {
    echo -e "${CYAN}=== Freeform Status ===${NC}"
    echo ""
    
    if is_freeform_supported; then
        echo -e "${GREEN}✓${NC} Freeform mode: ${GREEN}Enabled${NC}"
    else
        echo -e "${RED}✗${NC} Freeform mode: ${RED}Disabled${NC}"
        echo ""
        echo "Enable with: roblox-manager.sh freeform enable"
        return 1
    fi
    
    local resolution
    resolution=$(get_screen_resolution)
    echo -e "${BLUE}Screen resolution:${NC} $resolution"
    
    local layout
    layout=$(get_config "freeform_layout" "grid")
    echo -e "${BLUE}Layout mode:${NC} $layout"
    
    echo ""
}

#######################################
# Save current window layout
# Arguments:
#   $1 - Layout name
# Returns:
#   0 on success
#######################################
save_layout() {
    local layout_name="$1"
    
    log_info "Saving layout: $layout_name"
    
    # Get running instances and their positions
    # This is a placeholder - actual implementation would query window manager
    log_warn "Layout saving not yet fully implemented"
    
    # TODO: Save to config file
}

#######################################
# Restore saved window layout
# Arguments:
#   $1 - Layout name
# Returns:
#   0 on success
#######################################
restore_layout() {
    local layout_name="$1"
    
    log_info "Restoring layout: $layout_name"
    
    # TODO: Load from config and apply positions
    log_warn "Layout restoration not yet fully implemented"
}
