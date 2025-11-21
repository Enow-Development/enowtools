#!/data/data/com.termux/files/usr/bin/bash
# lib/clone-manager.sh - App cloning management using Android Multi-User
# Author: Roblox Manager Team
# Description: Create, manage, and update Roblox app clones using native Android users

# Shellcheck source
# shellcheck source=./utils.sh
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"

ACCOUNTS_FILE="${CONFIG_DIR}/accounts.json"

# Base user ID for clones (starting from 10 to avoid conflicts)
BASE_USER_ID=10

#######################################
# Initialize accounts file if not exists
#######################################
init_accounts_file() {
    if [ ! -f "$ACCOUNTS_FILE" ]; then
        echo '{"instances":[]}' > "$ACCOUNTS_FILE"
        log_debug "Created accounts file"
    fi
}

#######################################
# Get all instances from accounts.json
# Returns:
#   JSON array of instances
#######################################
get_all_instances() {
    init_accounts_file
    jq -r '.instances' "$ACCOUNTS_FILE"
}

#######################################
# Get instance by ID
# Arguments:
#   $1 - Instance ID
# Returns:
#   Instance JSON object or null
#######################################
get_instance() {
    local instance_id="$1"
    init_accounts_file
    jq -r ".instances[] | select(.id == \"$instance_id\")" "$ACCOUNTS_FILE"
}

#######################################
# Get instance count
# Returns:
#   Number of instances
#######################################
get_instance_count() {
    init_accounts_file
    jq -r '.instances | length' "$ACCOUNTS_FILE"
}

#######################################
# Add new instance to accounts.json
# Arguments:
#   $1 - Instance ID
#   $2 - User ID
#   $3 - Username (optional)
# Returns:
#   0 on success
#######################################
add_instance() {
    local instance_id="$1"
    local user_id="$2"
    local username="${3:-}"
    
    init_accounts_file
    
    local new_instance
    new_instance=$(jq -n \
        --arg id "$instance_id" \
        --arg uid "$user_id" \
        --arg uname "$username" \
        --arg status "stopped" \
        --arg ts "$(get_timestamp)" \
        '{
            id: $id,
            user_id: ($uid | tonumber),
            username: $uname,
            cookie: "",
            status: $status,
            pid: 0,
            last_started: $ts,
            restart_count: 0
        }')
    
    local tmp_file
    tmp_file=$(mktemp)
    
    jq ".instances += [$new_instance]" "$ACCOUNTS_FILE" > "$tmp_file" && mv "$tmp_file" "$ACCOUNTS_FILE"
    
    log_info "Added instance: $instance_id (user: $user_id)"
}

#######################################
# Update instance field
# Arguments:
#   $1 - Instance ID
#   $2 - Field name
#   $3 - New value
# Returns:
#   0 on success
#######################################
update_instance() {
    local instance_id="$1"
    local field="$2"
    local value="$3"
    
    init_accounts_file
    
    local tmp_file
    tmp_file=$(mktemp)
    
    # Handle numeric vs string values
    if [[ "$value" =~ ^[0-9]+$ ]]; then
        jq "(.instances[] | select(.id == \"$instance_id\") | .$field) = ($value | tonumber)" "$ACCOUNTS_FILE" > "$tmp_file"
    else
        jq "(.instances[] | select(.id == \"$instance_id\") | .$field) = \"$value\"" "$ACCOUNTS_FILE" > "$tmp_file"
    fi
    
    mv "$tmp_file" "$ACCOUNTS_FILE"
    log_debug "Updated instance $instance_id: $field = $value"
}

#######################################
# Remove instance from accounts.json
# Arguments:
#   $1 - Instance ID
# Returns:
#   0 on success
#######################################
remove_instance() {
    local instance_id="$1"
    
    init_accounts_file
    
    local tmp_file
    tmp_file=$(mktemp)
    
    jq ".instances = [.instances[] | select(.id != \"$instance_id\")]" "$ACCOUNTS_FILE" > "$tmp_file" && mv "$tmp_file" "$ACCOUNTS_FILE"
    
    log_info "Removed instance: $instance_id"
}

#######################################
# Create Android user
# Arguments:
#   $1 - User ID
#   $2 - User name
# Returns:
#   0 on success
#######################################
create_android_user() {
    local user_id="$1"
    local user_name="$2"
    
    log_info "Creating Android user: $user_name (ID: $user_id)"
    
    # Check if user already exists
    if adb_shell "pm list users" | grep -q "UserInfo{$user_id:"; then
        log_warn "User $user_id already exists"
        return 0
    fi
    
    # Create user
    local result
    result=$(adb_shell "pm create-user '$user_name'" 2>&1)
    
    if echo "$result" | grep -q "Success"; then
        log_success "User created: $user_name"
        
        # Start the user
        adb_shell "am start-user $user_id" >/dev/null 2>&1
        
        return 0
    else
        log_error "Failed to create user: $result"
        return 1
    fi
}

#######################################
# Delete Android user
# Arguments:
#   $1 - User ID
# Returns:
#   0 on success
#######################################
delete_android_user() {
    local user_id="$1"
    
    log_info "Deleting Android user: $user_id"
    
    # Stop user first
    adb_shell "am stop-user $user_id" >/dev/null 2>&1
    
    # Remove user
    local result
    result=$(adb_shell "pm remove-user $user_id" 2>&1)
    
    if echo "$result" | grep -q "Success"; then
        log_success "User deleted: $user_id"
        return 0
    else
        log_error "Failed to delete user: $result"
        return 1
    fi
}

#######################################
# Install APK for specific user
# Arguments:
#   $1 - APK path on device
#   $2 - User ID
# Returns:
#   0 on success
#######################################
install_apk_for_user() {
    local apk_path="$1"
    local user_id="$2"
    
    log_info "Installing APK for user $user_id..."
    
    # Install APK
    local result
    result=$(adb_shell "pm install --user $user_id '$apk_path'" 2>&1)
    
    if echo "$result" | grep -q "Success"; then
        log_success "APK installed for user $user_id"
        return 0
    else
        log_error "Failed to install APK: $result"
        return 1
    fi
}

#######################################
# Uninstall package for specific user
# Arguments:
#   $1 - Package name
#   $2 - User ID
# Returns:
#   0 on success
#######################################
uninstall_package_for_user() {
    local package="$1"
    local user_id="$2"
    
    log_info "Uninstalling $package for user $user_id..."
    
    local result
    result=$(adb_shell "pm uninstall --user $user_id '$package'" 2>&1)
    
    if echo "$result" | grep -q "Success"; then
        log_success "Package uninstalled for user $user_id"
        return 0
    else
        log_warn "Failed to uninstall package: $result"
        return 1
    fi
}

#######################################
# Create new clone
# Arguments:
#   $1 - Clone name (optional)
# Returns:
#   Instance ID
#######################################
create_clone() {
    local clone_name="$1"
    
    if ! adb_is_connected; then
        die "ADB not connected. Please connect ADB first."
    fi
    
    local package
    package=$(get_config "roblox_package")
    
    local apk_path
    apk_path=$(get_config "roblox_apk_path")
    
    # Validate APK exists on device
    if ! adb_shell "test -f '$apk_path' && echo 'exists'" | grep -q "exists"; then
        die "APK not found on device: $apk_path"
    fi
    
    # Get next available user ID
    local current_count
    current_count=$(get_instance_count)
    local user_id=$((BASE_USER_ID + current_count))
    
    # Generate instance ID
    local instance_id="roblox_${current_count}"
    
    # Set default clone name
    if [ -z "$clone_name" ]; then
        clone_name="Roblox_Clone_${current_count}"
    fi
    
    log_info "Creating clone: $instance_id"
    
    # Create Android user
    if ! create_android_user "$user_id" "$clone_name"; then
        die "Failed to create Android user"
    fi
    
    # Install APK for user
    if ! install_apk_for_user "$apk_path" "$user_id"; then
        delete_android_user "$user_id"
        die "Failed to install APK for user"
    fi
    
    # Add to accounts file
    add_instance "$instance_id" "$user_id" "$clone_name"
    
    log_success "Clone created successfully: $instance_id"
    echo "$instance_id"
}

#######################################
# Delete clone
# Arguments:
#   $1 - Instance ID
# Returns:
#   0 on success
#######################################
delete_clone() {
    local instance_id="$1"
    
    if ! adb_is_connected; then
        die "ADB not connected"
    fi
    
    local instance
    instance=$(get_instance "$instance_id")
    
    if [ -z "$instance" ] || [ "$instance" = "null" ]; then
        log_error "Instance not found: $instance_id"
        return 1
    fi
    
    local user_id
    user_id=$(echo "$instance" | jq -r '.user_id')
    
    log_info "Deleting clone: $instance_id (user: $user_id)"
    
    # Stop app if running
    stop_clone "$instance_id" 2>/dev/null || true
    
    # Delete Android user (this will also uninstall apps)
    delete_android_user "$user_id"
    
    # Remove from accounts
    remove_instance "$instance_id"
    
    log_success "Clone deleted: $instance_id"
}

#######################################
# Update all clones with new APK
# Arguments:
#   $1 - New APK path on device
# Returns:
#   0 on success
#######################################
update_all_clones() {
    local new_apk_path="${1:-}"
    
    if [ -z "$new_apk_path" ]; then
        new_apk_path=$(get_config "roblox_apk_path")
    fi
    
    if ! adb_is_connected; then
        die "ADB not connected"
    fi
    
    # Validate new APK
    if ! adb_shell "test -f '$new_apk_path' && echo 'exists'" | grep -q "exists"; then
        die "APK not found: $new_apk_path"
    fi
    
    log_info "Updating all clones with new APK..."
    
    local package
    package=$(get_config "roblox_package")
    
    # Get all instances
    local instances
    instances=$(get_all_instances | jq -r '.[] | @base64')
    
    if [ -z "$instances" ]; then
        log_warn "No instances to update"
        return 0
    fi
    
    local updated=0
    local failed=0
    
    for instance_b64 in $instances; do
        local instance
        instance=$(echo "$instance_b64" | base64 -d)
        
        local instance_id
        instance_id=$(echo "$instance" | jq -r '.id')
        
        local user_id
        user_id=$(echo "$instance" | jq -r '.user_id')
        
        log_info "Updating $instance_id (user: $user_id)..."
        
        # Stop app if running
        stop_clone "$instance_id" 2>/dev/null || true
        
        # Install new APK (this will update if already installed)
        if install_apk_for_user "$new_apk_path" "$user_id"; then
            ((updated++))
        else
            ((failed++))
        fi
    done
    
    log_success "Update complete: $updated updated, $failed failed"
}

#######################################
# Start clone (launch app)
# Arguments:
#   $1 - Instance ID
# Returns:
#   0 on success
#######################################
start_clone() {
    local instance_id="$1"
    
    if ! adb_is_connected; then
        die "ADB not connected"
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
    
    log_info "Starting $instance_id..."
    
    # Start the app
    adb_shell "am start --user $user_id -n ${package}/com.roblox.client.startup.ActivitySplash" >/dev/null 2>&1
    
    sleep 2
    
    # Get PID
    local pid
    pid=$(adb_shell "pidof -s $package" 2>/dev/null | tr -d '\r\n')
    
    if [ -n "$pid" ]; then
        update_instance "$instance_id" "status" "running"
        update_instance "$instance_id" "pid" "$pid"
        update_instance "$instance_id" "last_started" "$(get_timestamp)"
        
        log_success "$instance_id started (PID: $pid)"
        return 0
    else
        log_error "Failed to start $instance_id"
        update_instance "$instance_id" "status" "failed"
        return 1
    fi
}

#######################################
# Stop clone
# Arguments:
#   $1 - Instance ID
# Returns:
#   0 on success
#######################################
stop_clone() {
    local instance_id="$1"
    
    if ! adb_is_connected; then
        die "ADB not connected"
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
    
    log_info "Stopping $instance_id..."
    
    # Force stop the app
    adb_shell "am force-stop --user $user_id $package" >/dev/null 2>&1
    
    update_instance "$instance_id" "status" "stopped"
    update_instance "$instance_id" "pid" "0"
    
    log_success "$instance_id stopped"
}

#######################################
# List all clones
# Arguments:
#   None
# Returns:
#   Pretty formatted list
#######################################
list_clones() {
    local instances
    instances=$(get_all_instances)
    
    local count
    count=$(echo "$instances" | jq 'length')
    
    if [ "$count" -eq 0 ]; then
        echo "No clones found."
        return
    fi
    
    echo -e "${CYAN}=== Roblox Clones ===${NC}"
    echo ""
    
    echo "$instances" | jq -r '.[] | @base64' | while read -r instance_b64; do
        local instance
        instance=$(echo "$instance_b64" | base64 -d)
        
        local id
        id=$(echo "$instance" | jq -r '.id')
        
        local user_id
        user_id=$(echo "$instance" | jq -r '.user_id')
        
        local username
        username=$(echo "$instance" | jq -r '.username // "N/A"')
        
        local status
        status=$(echo "$instance" | jq -r '.status')
        
        local pid
        pid=$(echo "$instance" | jq -r '.pid // 0')
        
        # Color code status
        local status_color
        case "$status" in
            running) status_color=$GREEN ;;
            stopped) status_color=$YELLOW ;;
            failed) status_color=$RED ;;
            *) status_color=$NC ;;
        esac
        
        echo -e "${BLUE}ID:${NC} $id"
        echo -e "${BLUE}User ID:${NC} $user_id"
        echo -e "${BLUE}Username:${NC} $username"
        echo -e "${BLUE}Status:${NC} ${status_color}${status}${NC}"
        if [ "$pid" != "0" ]; then
            echo -e "${BLUE}PID:${NC} $pid"
        fi
        echo ""
    done
}
