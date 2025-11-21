#!/data/data/com.termux/files/usr/bin/bash
# lib/utils.sh - Core utility functions for Roblox Manager
# Author: Roblox Manager Team
# Description: Provides logging, error handling, ADB helpers, and JSON operations

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/config"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/roblox-manager.log"

# Color codes for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Log levels
LOG_LEVEL_DEBUG=0
LOG_LEVEL_INFO=1
LOG_LEVEL_WARN=2
LOG_LEVEL_ERROR=3

# Current log level (default: INFO)
CURRENT_LOG_LEVEL=$LOG_LEVEL_INFO

#######################################
# Initialize logging system
# Arguments:
#   None
# Returns:
#   0 on success
#######################################
init_logging() {
    mkdir -p "$LOG_DIR"
    touch "$LOG_FILE"
    
    # Read log level from config
    local config_log_level
    config_log_level=$(get_config "log_level" "info")
    
    case "$config_log_level" in
        debug) CURRENT_LOG_LEVEL=$LOG_LEVEL_DEBUG ;;
        info) CURRENT_LOG_LEVEL=$LOG_LEVEL_INFO ;;
        warn) CURRENT_LOG_LEVEL=$LOG_LEVEL_WARN ;;
        error) CURRENT_LOG_LEVEL=$LOG_LEVEL_ERROR ;;
    esac
}

#######################################
# Log message with timestamp and level
# Arguments:
#   $1 - Log level (DEBUG|INFO|WARN|ERROR)
#   $2 - Message
# Returns:
#   None
#######################################
log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    local level_num
    case "$level" in
        DEBUG) level_num=$LOG_LEVEL_DEBUG ;;
        INFO) level_num=$LOG_LEVEL_INFO ;;
        WARN) level_num=$LOG_LEVEL_WARN ;;
        ERROR) level_num=$LOG_LEVEL_ERROR ;;
        *) level_num=$LOG_LEVEL_INFO ;;
    esac
    
    # Only log if level is >= current log level
    if [ $level_num -ge $CURRENT_LOG_LEVEL ]; then
        # Write to log file
        echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
        
        # Print to console with colors
        local color
        case "$level" in
            DEBUG) color=$CYAN ;;
            INFO) color=$GREEN ;;
            WARN) color=$YELLOW ;;
            ERROR) color=$RED ;;
        esac
        
        echo -e "${color}[$level]${NC} $message"
    fi
}

#######################################
# Logging convenience functions
#######################################
log_debug() { log "DEBUG" "$1"; }
log_info() { log "INFO" "$1"; }
log_warn() { log "WARN" "$1"; }
log_error() { log "ERROR" "$1"; }

#######################################
# Print success message
# Arguments:
#   $1 - Message
#######################################
log_success() {
    echo -e "${GREEN}✓${NC} $1"
    log "INFO" "SUCCESS: $1"
}

#######################################
# Print error and exit
# Arguments:
#   $1 - Error message
#   $2 - Exit code (optional, default 1)
#######################################
die() {
    local message="$1"
    local exit_code="${2:-1}"
    log_error "$message"
    echo -e "${RED}✗ Error:${NC} $message" >&2
    exit "$exit_code"
}

#######################################
# Check if command exists
# Arguments:
#   $1 - Command name
# Returns:
#   0 if exists, 1 otherwise
#######################################
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

#######################################
# Check dependencies
# Arguments:
#   None
# Returns:
#   0 if all dependencies met, exits otherwise
#######################################
check_dependencies() {
    log_info "Checking dependencies..."
    
    local missing_deps=()
    
    # Required commands
    local required_commands=("jq" "adb")
    
    for cmd in "${required_commands[@]}"; do
        if ! command_exists "$cmd"; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        echo -e "${RED}Missing required dependencies:${NC}"
        for dep in "${missing_deps[@]}"; do
            echo "  - $dep"
        done
        echo ""
        echo "Install with: pkg install ${missing_deps[*]}"
        exit 1
    fi
    
    log_success "All dependencies installed"
}

#######################################
# Get config value from config.json
# Arguments:
#   $1 - Config key
#   $2 - Default value (optional)
# Returns:
#   Config value or default
#######################################
get_config() {
    local key="$1"
    local default="${2:-}"
    local config_file="${CONFIG_DIR}/config.json"
    
    if [ ! -f "$config_file" ]; then
        echo "$default"
        return
    fi
    
    local value
    value=$(jq -r ".${key} // \"${default}\"" "$config_file" 2>/dev/null)
    
    if [ -z "$value" ] || [ "$value" = "null" ]; then
        echo "$default"
    else
        echo "$value"
    fi
}

#######################################
# Set config value in config.json
# Arguments:
#   $1 - Config key
#   $2 - Value
# Returns:
#   0 on success
#######################################
set_config() {
    local key="$1"
    local value="$2"
    local config_file="${CONFIG_DIR}/config.json"
    
    if [ ! -f "$config_file" ]; then
        echo "{}" > "$config_file"
    fi
    
    local tmp_file
    tmp_file=$(mktemp)
    
    jq ".${key} = \"${value}\"" "$config_file" > "$tmp_file" && mv "$tmp_file" "$config_file"
    log_debug "Config updated: $key = $value"
}

#######################################
# ADB Helper: Check if ADB is connected
# Returns:
#   0 if connected, 1 otherwise
#######################################
adb_is_connected() {
    adb devices 2>/dev/null | grep -q "device$"
}

#######################################
# ADB Helper: Execute ADB shell command
# Arguments:
#   $@ - Command to execute
# Returns:
#   Command output
#######################################
adb_shell() {
    if ! adb_is_connected; then
        log_error "ADB not connected"
        return 1
    fi
    
    adb shell "$@" 2>/dev/null
}

#######################################
# ADB Helper: Get package name for user
# Arguments:
#   $1 - Package base name
#   $2 - User ID
# Returns:
#   Full package name
#######################################
adb_get_package() {
    local package="$1"
    local user_id="${2:-0}"
    
    adb_shell "pm list packages --user $user_id | grep '$package'" | cut -d':' -f2
}

#######################################
# ADB Helper: Check if package is installed for user
# Arguments:
#   $1 - Package name
#   $2 - User ID
# Returns:
#   0 if installed, 1 otherwise
#######################################
adb_package_installed() {
    local package="$1"
    local user_id="${2:-0}"
    
    adb_shell "pm list packages --user $user_id" | grep -q "package:${package}$"
}

#######################################
# ADB Helper: Get running processes
# Arguments:
#   $1 - Package name (optional)
# Returns:
#   Process list
#######################################
adb_get_processes() {
    local package="${1:-}"
    
    if [ -z "$package" ]; then
        adb_shell "ps -A"
    else
        adb_shell "ps -A | grep '$package'"
    fi
}

#######################################
# ADB Helper: Check if app is running
# Arguments:
#   $1 - Package name
#   $2 - User ID
# Returns:
#   0 if running, 1 otherwise
#######################################
adb_is_running() {
    local package="$1"
    local user_id="${2:-0}"
    
    adb_get_processes "$package" | grep -q "u${user_id}_"
}

#######################################
# Get APK version code
# Arguments:
#   $1 - APK file path
# Returns:
#   Version code
#######################################
get_apk_version() {
    local apk_path="$1"
    
    if [ ! -f "$apk_path" ]; then
        echo "0"
        return
    fi
    
    aapt dump badging "$apk_path" 2>/dev/null | grep "versionCode" | sed -n "s/.*versionCode='\([0-9]*\)'.*/\1/p"
}

#######################################
# Get installed package version
# Arguments:
#   $1 - Package name
#   $2 - User ID
# Returns:
#   Version code
#######################################
get_installed_version() {
    local package="$1"
    local user_id="${2:-0}"
    
    adb_shell "dumpsys package $package | grep versionCode" | head -n1 | sed -n 's/.*versionCode=\([0-9]*\).*/\1/p'
}

#######################################
# Validate JSON file
# Arguments:
#   $1 - JSON file path
# Returns:
#   0 if valid, 1 otherwise
#######################################
validate_json() {
    local json_file="$1"
    
    if [ ! -f "$json_file" ]; then
        return 1
    fi
    
    jq empty "$json_file" 2>/dev/null
}

#######################################
# Show progress spinner
# Arguments:
#   $1 - Message
#   $2 - PID to wait for
#######################################
show_spinner() {
    local message="$1"
    local pid="$2"
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    
    while kill -0 "$pid" 2>/dev/null; do
        i=$(( (i+1) % 10 ))
        printf "\r${CYAN}${spin:$i:1}${NC} %s" "$message"
        sleep 0.1
    done
    
    printf "\r${GREEN}✓${NC} %s\n" "$message"
}

#######################################
# Format timestamp
# Arguments:
#   $1 - Timestamp format (optional, default: '%Y-%m-%d %H:%M:%S')
# Returns:
#   Formatted timestamp
#######################################
get_timestamp() {
    local format="${1:-%Y-%m-%d %H:%M:%S}"
    date +"$format"
}

#######################################
# Convert seconds to human readable format
# Arguments:
#   $1 - Seconds
# Returns:
#   Human readable duration
#######################################
format_duration() {
    local seconds="$1"
    local days=$((seconds / 86400))
    local hours=$(( (seconds % 86400) / 3600 ))
    local minutes=$(( (seconds % 3600) / 60 ))
    local secs=$((seconds % 60))
    
    if [ $days -gt 0 ]; then
        echo "${days}d ${hours}h ${minutes}m"
    elif [ $hours -gt 0 ]; then
        echo "${hours}h ${minutes}m"
    elif [ $minutes -gt 0 ]; then
        echo "${minutes}m ${secs}s"
    else
        echo "${secs}s"
    fi
}

# Initialize logging on source
init_logging
