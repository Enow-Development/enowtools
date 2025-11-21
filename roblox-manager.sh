#!/data/data/com.termux/files/usr/bin/bash
# roblox-manager.sh - Main CLI for Roblox Manager
# Author: Roblox Manager Team
# Description: Manage multiple Roblox lite clones on cloudphone

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source libraries
source "${SCRIPT_DIR}/lib/utils.sh"
source "${SCRIPT_DIR}/lib/clone-manager.sh"
source "${SCRIPT_DIR}/lib/cookie-injector.sh"
source "${SCRIPT_DIR}/lib/freeform-manager.sh"
source "${SCRIPT_DIR}/lib/monitor.sh"

VERSION="1.0.0"

#######################################
# Show version
#######################################
show_version() {
    echo "Roblox Manager v${VERSION}"
    echo "Cloudphone Edition"
}

#######################################
# Show help
#######################################
show_help() {
    cat << EOF
${CYAN}Roblox Manager${NC} - Manage multiple Roblox lite clones

${YELLOW}Usage:${NC}
    $(basename "$0") [command] [options]

${YELLOW}Commands:${NC}
    ${GREEN}init${NC}                          Initialize and check dependencies
    ${GREEN}clone${NC} <count> [name]          Create N clones (optional name prefix)
    ${GREEN}delete${NC} <instance_id>          Delete a specific clone
    ${GREEN}list${NC}                          List all clones and their status
    ${GREEN}start${NC} <instance_id>           Start a specific clone
    ${GREEN}stop${NC} <instance_id>            Stop a specific clone
    ${GREEN}update${NC} [apk_path]             Update all clones with new APK
    
    ${GREEN}inject${NC} <instance_id>          Inject cookie for a clone (interactive)
    ${GREEN}inject-all${NC}                    Inject all saved cookies
    ${GREEN}set-cookie${NC} <instance_id>      Set cookie for a clone (save only)
    
    ${GREEN}launch${NC} <instance_id...>       Launch instances in freeform mode
    ${GREEN}launch-all${NC}                    Launch all instances in freeform
    ${GREEN}freeform${NC} enable|disable       Enable/disable freeform mode
    ${GREEN}freeform${NC} status               Check freeform status
    ${GREEN}rearrange${NC}                     Rearrange freeform windows
    
    ${GREEN}monitor${NC} start                 Start monitoring daemon
    ${GREEN}monitor${NC} stop                  Stop monitoring daemon
    ${GREEN}monitor${NC} restart               Restart monitoring daemon
    ${GREEN}monitor${NC} status                Show monitor status
    ${GREEN}monitor${NC} logs [lines]          View monitor logs
    
    ${GREEN}config${NC} get <key>              Get config value
    ${GREEN}config${NC} set <key> <value>      Set config value
    
    ${GREEN}version${NC}                       Show version
    ${GREEN}help${NC}                          Show this help

${YELLOW}Examples:${NC}
    # Initialize
    $(basename "$0") init
    
    # Create 4 clones
    $(basename "$0") clone 4
    
    # Set cookie for first clone
    $(basename "$0") set-cookie roblox_0
    
    # Launch all in freeform
    $(basename "$0") launch-all
    
    # Start monitoring
    $(basename "$0") monitor start

${YELLOW}Configuration:${NC}
    Config file: ${CONFIG_DIR}/config.json
    Accounts file: ${CONFIG_DIR}/accounts.json
    Logs: ${LOG_DIR}/

${YELLOW}Documentation:${NC}
    See README.md for detailed documentation

EOF
}

#######################################
# Initialize command
#######################################
cmd_init() {
    echo -e "${CYAN}=== Initializing Roblox Manager ===${NC}"
    echo ""
    
    # Check dependencies
    check_dependencies
    
    # Check ADB connection
    echo -n "Checking ADB connection... "
    if adb_is_connected; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"
        echo ""
        echo -e "${YELLOW}Warning:${NC} ADB not connected"
        echo "Make sure ADB is enabled and connected"
        return 1
    fi
    
    # Check config
    echo -n "Checking configuration... "
    if [ -f "${CONFIG_DIR}/config.json" ]; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${YELLOW}Creating default config${NC}"
    fi
    
    # Validate APK
    local apk_path
    apk_path=$(get_config "roblox_apk_path")
    
    echo -n "Checking Roblox APK... "
    if adb_shell "test -f '$apk_path' && echo 'exists'" | grep -q "exists"; then
        echo -e "${GREEN}✓${NC}"
        
        # Show APK info
        local package
        package=$(get_config "roblox_package")
        echo -e "  ${BLUE}Package:${NC} $package"
        echo -e "  ${BLUE}APK Path:${NC} $apk_path"
    else
        echo -e "${RED}✗${NC}"
        echo ""
        echo -e "${YELLOW}Warning:${NC} APK not found at: $apk_path"
        echo "Please update the path in config.json or place your APK at that location"
    fi
    
    # Check freeform support
    echo -n "Checking freeform support... "
    if is_freeform_supported; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${YELLOW}Not enabled${NC}"
        echo "  Enable with: $(basename "$0") freeform enable"
    fi
    
    echo ""
    log_success "Initialization complete"
}

#######################################
# Clone command
#######################################
cmd_clone() {
    local count="${1:-1}"
    local name_prefix="${2:-Roblox_Clone}"
    
    if ! [[ "$count" =~ ^[0-9]+$ ]] || [ "$count" -lt 1 ]; then
        die "Invalid count: $count"
    fi
    
    log_info "Creating $count clone(s)..."
    
    for ((i=0; i<count; i++)); do
        local clone_name="${name_prefix}_${i}"
        create_clone "$clone_name"
        echo ""
    done
    
    log_success "Created $count clone(s)"
    echo ""
    cmd_list
}

#######################################
# List command
#######################################
cmd_list() {
    list_clones
}

#######################################
# Config commands
#######################################
cmd_config() {
    local action="$1"
    local key="$2"
    local value="$3"
    
    case "$action" in
        get)
            if [ -z "$key" ]; then
                die "Usage: config get <key>"
            fi
            
            local result
            result=$(get_config "$key")
            echo "$result"
            ;;
        set)
            if [ -z "$key" ] || [ -z "$value" ]; then
                die "Usage: config set <key> <value>"
            fi
            
            set_config "$key" "$value"
            log_success "Config updated: $key = $value"
            ;;
        *)
            die "Invalid config action: $action (use get or set)"
            ;;
    esac
}

#######################################
# Main entry point
#######################################
main() {
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi
    
    local command="$1"
    shift
    
    case "$command" in
        init)
            cmd_init
            ;;
        clone)
            cmd_clone "$@"
            ;;
        delete)
            if [ -z "$1" ]; then
                die "Usage: delete <instance_id>"
            fi
            delete_clone "$1"
            ;;
        list)
            cmd_list
            ;;
        start)
            if [ -z "$1" ]; then
                die "Usage: start <instance_id>"
            fi
            start_clone "$1"
            ;;
        stop)
            if [ -z "$1" ]; then
                die "Usage: stop <instance_id>"
            fi
            stop_clone "$1"
            ;;
        update)
            update_all_clones "$@"
            ;;
        inject)
            if [ -z "$1" ]; then
                die "Usage: inject <instance_id>"
            fi
            
            local cookie
            cookie=$(read_cookie_input)
            if [ $? -eq 0 ]; then
                inject_cookie "$1" "$cookie"
            fi
            ;;
        inject-all)
            inject_all_cookies
            ;;
        set-cookie)
            if [ -z "$1" ]; then
                die "Usage: set-cookie <instance_id>"
            fi
            
            local cookie
            cookie=$(read_cookie_input)
            if [ $? -eq 0 ]; then
                set_instance_cookie "$1" "$cookie"
            fi
            ;;
        launch)
            if [ -z "$1" ]; then
                die "Usage: launch <instance_id> [instance_id...]"
            fi
            launch_all_freeform "$@"
            ;;
        launch-all)
            launch_all_instances_freeform
            ;;
        freeform)
            local action="${1:-status}"
            case "$action" in
                enable)
                    enable_freeform
                    ;;
                disable)
                    disable_freeform
                    ;;
                status)
                    check_freeform_status
                    ;;
                *)
                    die "Invalid freeform action: $action (use enable, disable, or status)"
                    ;;
            esac
            ;;
        rearrange)
            rearrange_freeform_windows
            ;;
        monitor)
            local action="${1:-status}"
            case "$action" in
                start)
                    start_monitor
                    ;;
                stop)
                    stop_monitor
                    ;;
                restart)
                    restart_monitor
                    ;;
                status)
                    monitor_status
                    ;;
                logs)
                    view_monitor_logs "${2:-20}"
                    ;;
                *)
                    die "Invalid monitor action: $action"
                    ;;
            esac
            ;;
        config)
            cmd_config "$@"
            ;;
        version)
            show_version
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo -e "${RED}Unknown command: $command${NC}"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Run main
main "$@"
