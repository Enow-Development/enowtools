#!/data/data/com.termux/files/usr/bin/bash
# lib/cookie-injector.sh - Cookie injection for Roblox authentication
# Author: Roblox Manager Team
# Description: Inject .ROBLOSECURITY cookies into Roblox app data via ADB

# Shellcheck source
# shellcheck source=./utils.sh
source "$(dirname "${BASH_SOURCE[0]}")/utils.sh"
# shellcheck source=./clone-manager.sh
source "$(dirname "${BASH_SOURCE[0]}")/clone-manager.sh"

#######################################
# Validate cookie format
# Arguments:
#   $1 - Cookie value
# Returns:
#   0 if valid, 1 otherwise
#######################################
validate_cookie() {
    local cookie="$1"
    
    # Check if cookie starts with expected pattern
    if [[ ! "$cookie" =~ ^_\|WARNING:-DO-NOT-SHARE-THIS\.--Sharing-this-will-allow-someone-to-log-in-as-you-and-to-steal-your-ROBUX-and-items\.\|_ ]]; then
        log_error "Invalid cookie format"
        return 1
    fi
    
    # Check minimum length
    if [ ${#cookie} -lt 50 ]; then
        log_error "Cookie too short, likely invalid"
        return 1
    fi
    
    return 0
}

#######################################
# Get app data directory for user
# Arguments:
#   $1 - Package name
#   $2 - User ID
# Returns:
#   Data directory path
#######################################
get_app_data_dir() {
    local package="$1"
    local user_id="$2"
    
    # For multi-user, data is stored in /data/user/<user_id>/<package>
    if [ "$user_id" -eq 0 ]; then
        echo "/data/data/${package}"
    else
        echo "/data/user/${user_id}/${package}"
    fi
}

#######################################
# Inject cookie via SharedPreferences
# Arguments:
#   $1 - Instance ID
#   $2 - Cookie value
# Returns:
#   0 on success
#######################################
inject_cookie_sharedprefs() {
    local instance_id="$1"
    local cookie="$2"
    
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
    
    local data_dir
    data_dir=$(get_app_data_dir "$package" "$user_id")
    
    log_info "Injecting cookie for $instance_id (user: $user_id)..."
    
    # SharedPreferences path (common location for Roblox)
    local prefs_dir="${data_dir}/shared_prefs"
    local prefs_file="${prefs_dir}/RobloxSettings.xml"
    
    # Check if app has been run at least once (data directory exists)
    if ! adb_shell "test -d '$data_dir' && echo 'exists'" | grep -q "exists"; then
        log_warn "App data directory doesn't exist. Starting app first..."
        start_clone "$instance_id"
        sleep 5
        stop_clone "$instance_id"
        sleep 2
    fi
    
    # Create shared_prefs directory if not exists
    adb_shell "mkdir -p '$prefs_dir'" 2>/dev/null
    
    # Create or update SharedPreferences XML
    local xml_content="<?xml version='1.0' encoding='utf-8' standalone='yes' ?>
<map>
    <string name=\".ROBLOSECURITY\">$cookie</string>
</map>"
    
    # Write to temp file and push
    local temp_file
    temp_file=$(mktemp)
    echo "$xml_content" > "$temp_file"
    
    # Push to device
    if adb push "$temp_file" "$prefs_file" >/dev/null 2>&1; then
        # Set correct permissions
        adb_shell "chmod 660 '$prefs_file'" 2>/dev/null
        adb_shell "chown $(adb_shell "stat -c '%u:%g' '$data_dir'" 2>/dev/null) '$prefs_file'" 2>/dev/null
        
        rm -f "$temp_file"
        
        log_success "Cookie injected successfully via SharedPreferences"
        return 0
    else
        rm -f "$temp_file"
        log_error "Failed to push cookie file"
        return 1
    fi
}

#######################################
# Inject cookie via SQLite database
# Arguments:
#   $1 - Instance ID
#   $2 - Cookie value
# Returns:
#   0 on success
#######################################
inject_cookie_sqlite() {
    local instance_id="$1"
    local cookie="$2"
    
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
    
    local data_dir
    data_dir=$(get_app_data_dir "$package" "$user_id")
    
    log_info "Attempting cookie injection via SQLite..."
    
    # Common database locations
    local db_paths=(
        "${data_dir}/databases/RobloxStorage.db"
        "${data_dir}/databases/WebStorage.db"
        "${data_dir}/app_webview/Cookies"
    )
    
    for db_path in "${db_paths[@]}"; do
        if adb_shell "test -f '$db_path' && echo 'exists'" | grep -q "exists"; then
            log_debug "Found database: $db_path"
            
            # Pull database
            local temp_db
            temp_db=$(mktemp)
            
            if adb pull "$db_path" "$temp_db" >/dev/null 2>&1; then
                # Try to inject cookie into database
                # This is app-specific and may need adjustment
                sqlite3 "$temp_db" "CREATE TABLE IF NOT EXISTS cookies (name TEXT, value TEXT);" 2>/dev/null
                sqlite3 "$temp_db" "INSERT OR REPLACE INTO cookies (name, value) VALUES ('.ROBLOSECURITY', '$cookie');" 2>/dev/null
                
                # Push back
                if adb push "$temp_db" "$db_path" >/dev/null 2>&1; then
                    rm -f "$temp_db"
                    log_success "Cookie injected via SQLite"
                    return 0
                fi
                
                rm -f "$temp_db"
            fi
        fi
    done
    
    log_warn "No suitable database found for SQLite injection"
    return 1
}

#######################################
# Inject cookie (tries multiple methods)
# Arguments:
#   $1 - Instance ID
#   $2 - Cookie value
# Returns:
#   0 on success
#######################################
inject_cookie() {
    local instance_id="$1"
    local cookie="$2"
    
    # Validate cookie
    if ! validate_cookie "$cookie"; then
        log_error "Cookie validation failed"
        return 1
    fi
    
    log_info "Injecting cookie for $instance_id..."
    
    # Try SharedPreferences first (most common)
    if inject_cookie_sharedprefs "$instance_id" "$cookie"; then
        # Update accounts.json with cookie
        update_instance "$instance_id" "cookie" "$cookie"
        log_success "Cookie injection completed"
        return 0
    fi
    
    # Fallback to SQLite
    if inject_cookie_sqlite "$instance_id" "$cookie"; then
        update_instance "$instance_id" "cookie" "$cookie"
        log_success "Cookie injection completed"
        return 0
    fi
    
    log_error "All cookie injection methods failed"
    log_warn "You may need to login manually"
    return 1
}

#######################################
# Set cookie for instance (save to config)
# Arguments:
#   $1 - Instance ID
#   $2 - Cookie value
# Returns:
#   0 on success
#######################################
set_instance_cookie() {
    local instance_id="$1"
    local cookie="$2"
    
    # Validate cookie
    if ! validate_cookie "$cookie"; then
        return 1
    fi
    
    # Store in accounts.json
    update_instance "$instance_id" "cookie" "$cookie"
    
    log_success "Cookie saved for $instance_id"
}

#######################################
# Get cookie for instance
# Arguments:
#   $1 - Instance ID
# Returns:
#   Cookie value
#######################################
get_instance_cookie() {
    local instance_id="$1"
    
    local instance
    instance=$(get_instance "$instance_id")
    
    if [ -z "$instance" ] || [ "$instance" = "null" ]; then
        log_error "Instance not found: $instance_id"
        return 1
    fi
    
    echo "$instance" | jq -r '.cookie // ""'
}

#######################################
# Inject all saved cookies
# Arguments:
#   None
# Returns:
#   Number of successful injections
#######################################
inject_all_cookies() {
    log_info "Injecting cookies for all instances..."
    
    local instances
    instances=$(get_all_instances | jq -r '.[] | @base64')
    
    if [ -z "$instances" ]; then
        log_warn "No instances found"
        return 0
    fi
    
    local success=0
    local failed=0
    
    for instance_b64 in $instances; do
        local instance
        instance=$(echo "$instance_b64" | base64 -d)
        
        local instance_id
        instance_id=$(echo "$instance" | jq -r '.id')
        
        local cookie
        cookie=$(echo "$instance" | jq -r '.cookie // ""')
        
        if [ -z "$cookie" ] || [ "$cookie" = "null" ]; then
            log_debug "No cookie set for $instance_id, skipping"
            continue
        fi
        
        if inject_cookie "$instance_id" "$cookie"; then
            ((success++))
        else
            ((failed++))
        fi
    done
    
    log_success "Cookie injection complete: $success successful, $failed failed"
    echo "$success"
}

#######################################
# Clear cookie for instance
# Arguments:
#   $1 - Instance ID
# Returns:
#   0 on success
#######################################
clear_instance_cookie() {
    local instance_id="$1"
    
    update_instance "$instance_id" "cookie" ""
    log_success "Cookie cleared for $instance_id"
}

#######################################
# Extract cookie from browser/manual input
# This is a helper for users to paste their cookie
# Arguments:
#   None
# Returns:
#   Cookie value from stdin
#######################################
read_cookie_input() {
    echo -e "${YELLOW}Paste your .ROBLOSECURITY cookie:${NC}"
    echo -e "${CYAN}(Tip: Get this from your browser's cookies for roblox.com)${NC}"
    echo ""
    
    read -r cookie
    
    if validate_cookie "$cookie"; then
        echo "$cookie"
        return 0
    else
        log_error "Invalid cookie format"
        return 1
    fi
}
