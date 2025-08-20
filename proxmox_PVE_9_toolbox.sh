#!/usr/bin/env bash
set -euo pipefail

# Script configuration
readonly SCRIPT_NAME="Proxmox Post Install Script"
readonly SCRIPT_VERSION="9.2"
readonly SCRIPT_AUTHOR="Bennell IT"
readonly SCRIPT_URL="www.bennellit.com.au"

# Color definitions
readonly COLOR_YELLOW='\033[33m'
readonly COLOR_RED='\033[01;31m'
readonly COLOR_GREEN='\033[1;92m'
readonly COLOR_CLEAR='\033[m'
readonly BFR="\\r\\033[K"
readonly HOLD="-"
readonly CHECK_MARK="${COLOR_GREEN}✓${COLOR_CLEAR}"
readonly CROSS="${COLOR_RED}✗${COLOR_CLEAR}"

# System detection
readonly HOSTNAME=$(hostname)
readonly TIMESTAMP=$(date +%Y_%m_%d-%H_%M_%S)
readonly PVE_LOG_FOLDER="/var/log/pve/tasks/"

# Configuration directories
readonly CONFIG_DIR="/usr/share/proxmox-patch"
readonly ENABLE_DIR="${CONFIG_DIR}/enable"
readonly FIRST_RUN_MARKER="${CONFIG_DIR}/firstrun"

# Logging
readonly LOG_FILE="/var/log/proxmox-post-install.log"

# Function to log messages
log_message() {
    local level="$1"
    shift
    local message="$*"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" | tee -a "$LOG_FILE"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "Error: Please run as root or with sudo" >&2
        exit 1
    fi
}

# Improved error handling
error_handler() {
    local line_no=$1
    local error_code=$2
    log_message "ERROR" "Script failed at line $line_no with exit code $error_code"
    echo "Error: Script failed at line $line_no. Check $LOG_FILE for details." >&2
    exit "$error_code"
}

trap 'error_handler ${LINENO} $?' ERR

# Function to display messages
msg_info() {
    local msg="$1"
    echo -ne " ${HOLD} ${COLOR_YELLOW}${msg}...${COLOR_CLEAR}"
    log_message "INFO" "$msg"
}

msg_ok() {
    local msg="$1"
    echo -e "${BFR} ${CHECK_MARK} ${COLOR_GREEN}${msg}${COLOR_CLEAR}"
    log_message "SUCCESS" "$msg"
}

msg_error() {
    local msg="$1"
    echo -e "${BFR} ${CROSS} ${COLOR_RED}${msg}${COLOR_CLEAR}"
    log_message "ERROR" "$msg"
}

# Get PVE version information
get_pve_version() {
    local pve_ver
    pve_ver="$(pveversion | awk -F'/' '{print $2}' | awk -F'-' '{print $1}')"
    echo "$pve_ver"
}

get_pve_major_minor() {
    local ver="$1"
    local major minor
    IFS='.' read -r major minor _ <<<"$ver"
    echo "$major $minor"
}

# Detect system type
detect_system_type() {
    if [[ -d "$PVE_LOG_FOLDER" ]]; then
        echo "pve"
    else
        echo "unknown"
    fi
}

# Backup file with timestamp
backup_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        cp "$file" "${file}.backup.${TIMESTAMP}"
        log_message "INFO" "Backed up $file to ${file}.backup.${TIMESTAMP}"
    fi
}

# Check if package is installed
is_package_installed() {
    local package="$1"
    dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q "ok installed"
}

# Install package if not already installed
install_package() {
    local package="$1"
    if ! is_package_installed "$package"; then
        msg_info "Installing $package"
        apt-get install -y "$package" &>/dev/null
        msg_ok "$package installed"
    else
        log_message "INFO" "$package already installed"
    fi
}

# Download with verification
download_file() {
    local url="$1"
    local destination="$2"
    local expected_checksum="${3:-}"
    
    if ! wget -q --timeout=30 --tries=3 -O "$destination" "$url"; then
        msg_error "Failed to download from $url"
        return 1
    fi
    
    # Verify checksum if provided
    if [[ -n "$expected_checksum" ]]; then
        local actual_checksum
        actual_checksum=$(sha256sum "$destination" | cut -d' ' -f1)
        if [[ "$actual_checksum" != "$expected_checksum" ]]; then
            msg_error "Checksum verification failed for $destination"
            rm -f "$destination"
            return 1
        fi
    fi
    
    return 0
}

# Header display
display_header() {
    clear
    cat << EOF
${COLOR_RED}
    ____                                 __    __           ____  ______
   / __ )  ___    ____    ____   ___    / /   / /          /  _/ /_  __/
  / __  | / _ \  / __ \  / __ \ / _ \  / /   / /           / /    / /
 / /_/ / /  __/ / / / / / / / //  __/ / /   / /          _/ /    / /
/_____/  \___/ /_/ /_/ /_/ /_/ \___/ /_/   /_/          /___/   /_/

                     $SCRIPT_URL
                 $SCRIPT_NAME v$SCRIPT_VERSION
                      by $SCRIPT_AUTHOR
${COLOR_CLEAR}
EOF
    sleep 2
}

# Improved first run setup with version detection
first_run_setup() {
    if [[ -f "$FIRST_RUN_MARKER" ]]; then
        return 0
    fi
    
    msg_info "Performing first run setup"
    
    # Create necessary directories
    mkdir -p "$CONFIG_DIR" "$ENABLE_DIR"
    
    # Detect PVE version and system type
    local pve_version pve_major system_type
    system_type=$(detect_system_type)
    
    if [[ "$system_type" == "pve" ]]; then
        pve_version="$(get_pve_version)"
        read -r pve_major _ <<<"$(get_pve_major_minor "$pve_version")"
        log_message "INFO" "Detected Proxmox VE $pve_version (system type: $system_type)"
        
        # Check if it's PVE 9
        if [[ "$pve_major" != "9" ]]; then
            msg_error "This script only supports Proxmox VE 9.x. Detected version: $pve_version"
            exit 1
        fi
        
        echo "$pve_major" > "$CONFIG_DIR/pve_version"
    else
        msg_error "This script only supports Proxmox VE 9.x systems"
        exit 1
    fi
    
    # Mark first run as complete
    echo "true" > "$FIRST_RUN_MARKER"
    msg_ok "First run setup completed"
}

# Configure repositories for Proxmox VE 9.x (deb822 format) - Clean Reset Only
configure_pve9_repositories() {
    msg_info "Configuring Proxmox VE 9.x repositories (deb822 format)"
    
    # Show warning about clean reset
    if ! whiptail --yesno \
"CLEAN REPOSITORY RESET

This will:
• Back up all current repository files
• Remove ALL existing APT sources
• Create clean deb822 format repositories
• Configure standard PVE 9 setup

This ensures a clean, consistent configuration and is the recommended approach for Proxmox VE 9.

Continue with repository configuration?" 16 60; then
        msg_ok "Repository configuration cancelled"
        return 0
    fi
    
    msg_info "Performing clean repository reset"
    
    # Create backup
    local backup_dir="${CONFIG_DIR}/repo-backup-${TIMESTAMP}"
    mkdir -p "$backup_dir"
    
    msg_info "Backing up current repositories to $backup_dir"
    if [[ -f /etc/apt/sources.list ]]; then
        cp /etc/apt/sources.list "$backup_dir/" 2>/dev/null || true
    fi
    if [[ -d /etc/apt/sources.list.d ]] && [[ -n "$(ls -A /etc/apt/sources.list.d/ 2>/dev/null)" ]]; then
        cp -r /etc/apt/sources.list.d/* "$backup_dir/" 2>/dev/null || true
    fi
    
    # Clean all existing repository files
    msg_info "Removing all existing repository files"
    rm -f /etc/apt/sources.list
    rm -f /etc/apt/sources.list.d/*.list
    rm -f /etc/apt/sources.list.d/*.sources
    mkdir -p /etc/apt/sources.list.d
    
    # Create clean deb822 repositories
    msg_info "Creating clean Debian Trixie repositories"
    cat > /etc/apt/sources.list.d/debian.sources <<'EOF'
Enabled: yes
Types: deb
URIs: http://deb.debian.org/debian/
Suites: trixie
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Enabled: yes
Types: deb
URIs: http://deb.debian.org/debian/
Suites: trixie-updates
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Enabled: yes
Types: deb
URIs: http://security.debian.org/debian-security/
Suites: trixie-security
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF
    
    msg_info "Creating Proxmox no-subscription repository"
    cat > /etc/apt/sources.list.d/proxmox.sources <<'EOF'
Enabled: yes
Types: deb
URIs: http://download.proxmox.com/debian/pve
Suites: trixie
Components: pve-no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
EOF
    
    msg_info "Creating Proxmox enterprise repository (disabled)"
    cat > /etc/apt/sources.list.d/pve-enterprise.sources <<'EOF'
Enabled: no
Types: deb
URIs: https://enterprise.proxmox.com/debian/pve
Suites: trixie
Components: pve-enterprise
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
EOF
    
    msg_info "Creating Ceph repository (disabled)"
    cat > /etc/apt/sources.list.d/ceph.sources <<'EOF'
Enabled: no
Types: deb
URIs: http://download.proxmox.com/debian/ceph-squid
Suites: trixie
Components: no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
EOF
    
    msg_info "Creating PVE test repository (disabled)"
    cat > /etc/apt/sources.list.d/pve-test.sources <<'EOF'
Enabled: no
Types: deb
URIs: http://download.proxmox.com/debian/pve
Suites: trixie
Components: pve-test
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
EOF
    
    msg_ok "Clean repository configuration completed"
    log_message "INFO" "Repository backup created at: $backup_dir"
    
    # Show what was configured
    whiptail --title "Repository Configuration Complete" --msgbox \
"✅ CLEAN REPOSITORIES CONFIGURED:

ENABLED:
• Debian Trixie (main, contrib, non-free, non-free-firmware)
• Proxmox no-subscription repository

DISABLED (can be enabled later):
• Proxmox enterprise repository
• Ceph repository  
• PVE test repository

BACKUP LOCATION:
$backup_dir

TO ENABLE DISABLED REPOSITORIES:
Edit the .sources files and change 'Enabled: no' to 'Enabled: yes'" 20 75
}

# System update
system_update() {
    msg_info "Updating system packages"
    apt-get update -y -qq || { msg_error "apt update failed"; return 1; }
    apt-get upgrade -y -qq || { msg_error "apt upgrade failed"; return 1; }
    apt-get dist-upgrade -y -qq || { msg_error "apt dist-upgrade failed"; return 1; }
    msg_ok "System updated successfully"
}

# Configure repositories
configure_repositories() {
    configure_pve9_repositories
    system_update
}

# Install useful dependencies
install_dependencies() {
    msg_info "Installing useful dependencies"
    
    local packages=("ifupdown2" "git" "sudo" "libsasl2-modules" "curl" "wget")
    
    for package in "${packages[@]}"; do
        install_package "$package"
    done
    
    msg_ok "Dependencies installed"
}

# Install subscription bypass (warning removed)
install_subscription_bypass() {
    msg_info "Installing Bennell IT subscription bypass"
    
    # Remove existing installation
    if is_package_installed "pve-bit-subscription"; then
        apt purge pve-bit-subscription -y &>/dev/null
    fi
    
    # Download and install latest version
    local latest_url
    latest_url=$(curl -s https://api.github.com/repos/sbennell/pve-bit-subscription/releases/latest | grep "browser_download_url.*deb" | cut -d '"' -f 4)
    
    if [[ -n "$latest_url" ]]; then
        local temp_file="/tmp/pve-bit-subscription.deb"
        if download_file "$latest_url" "$temp_file"; then
            dpkg -i "$temp_file" &>/dev/null
            rm -f "$temp_file"
            
            # Block license check server
            if ! grep -q "127.0.0.1 shop.maurer-it.com" /etc/hosts; then
                echo "127.0.0.1 shop.maurer-it.com" >> /etc/hosts
                log_message "INFO" "Blocked shop.maurer-it.com"
            fi
            
            echo "true" > "$ENABLE_DIR/BITsubscription"
            msg_ok "Subscription bypass installed"
        else
            msg_error "Failed to download subscription bypass package"
        fi
    else
        msg_error "Failed to get latest release URL"
    fi
}

# Add login banner
add_login_banner() {
    msg_info "Adding Bennell IT login banner"
    
    # Remove existing banner
    rm -f "$ENABLE_DIR/pvebanner" /usr/bin/pvebanner
    
    if download_file "https://raw.githubusercontent.com/sbennell/SetupProxmox/master/files/pvebanner" "/usr/bin/pvebanner"; then
        chmod +x /usr/bin/pvebanner
        /usr/bin/pvebanner
        echo "true" > "$ENABLE_DIR/pvebanner"
        msg_ok "Login banner added"
    else
        msg_error "Failed to install login banner"
    fi
}

# Add SSH key with security confirmation
add_ssh_key() {
    msg_info "Adding Bennell IT SSH key"
    
    # Simple security confirmation
    if ! whiptail --yesno "Add Bennell IT SSH key for remote access?\n\nWARNING: This provides third-party access to your system.\nOnly proceed if you trust Bennell IT completely." 10 60; then
        msg_ok "SSH key installation cancelled by user"
        return 0
    fi
    
    local ssh_dir="/root/.ssh"
    local auth_keys="$ssh_dir/authorized_keys"
    local ssh_key="ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEAkXk0+tC1ZMiWgTQvE/GeB9+TuPWTf8mr9zVOYdNhF+KFXxc/DjMjIPNCAUxtQErlush1GF87b7gaEIC2F5p/+xr39gnt5panjT2AJmVQm9GrSc0LwZOHducgB9SeW7F6A2hA0dtEDxOPHC88ipT9qvTZdeC+mgoNmyIAIMmnPVcZOqQm7iVUf3kJCRWVGI/csE1UYpZ1tLpkaNqjP0Iy7cQvNgodJWh8Mg//TD6ESKBQ35P3+6zT2zEpIK/hQ5eaW5Uu82kSt1ZGuNaPukfCra0cjWr2n4hC+C3E9m3K/3ZV43usaxwSbPa6R/jJE4fyqpC2hqdTKW8Z66mVTC8EpQ== Bennell IT"
    
    # Create SSH directory and authorized_keys file
    mkdir -p "$ssh_dir"
    touch "$auth_keys"
    
    # Add key if not already present
    if ! grep -q "Bennell IT" "$auth_keys"; then
        echo "$ssh_key" >> "$auth_keys"
        chmod 700 "$ssh_dir"
        chmod 600 "$auth_keys"
        msg_ok "SSH key added"
    else
        msg_ok "SSH key already present"
    fi
}

# Setup SMTP
setup_smtp() {
    msg_info "Setting up SMTP configuration"
    
    if download_file "https://raw.githubusercontent.com/sbennell/SetupProxmox/master/scripts/smtp.sh" "/tmp/smtp_setup.sh"; then
        chmod +x /tmp/smtp_setup.sh
        bash /tmp/smtp_setup.sh
        rm -f /tmp/smtp_setup.sh
        msg_ok "SMTP setup completed"
    else
        msg_error "Failed to download SMTP setup script"
    fi
}

# Disable subscription nag message
disable_subscription_nag() {
    if whiptail --yesno "Disable subscription nag message?" 8 60; then
        whiptail --msgbox "Supporting the software's development team is essential. Check their official website's Support Subscriptions for pricing." 8 60
        
        msg_info "Disabling subscription nag"
        cat > /etc/apt/apt.conf.d/no-nag-script << 'EOF'
DPkg::Post-Invoke { "if [ -s /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js ] && ! grep -q -F 'NoMoreNagging' /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js; then echo 'Removing subscription nag from UI...'; sed -i '/data\.status/{s/\\!//;s/active/NoMoreNagging/}' /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js; fi" };
EOF
        
        # Reinstall widget toolkit to apply changes
        apt --reinstall install proxmox-widget-toolkit &>/dev/null || true
        
        msg_ok "Disabled subscription nag (Clear browser cache)"
    fi
}

# Educational messages and warnings

# Check if HA services are running
is_ha_active() {
    systemctl is-active --quiet pve-ha-lrm 2>/dev/null
}

# Enable High Availability services
enable_ha_services() {
    msg_info "Enabling High Availability services"
    
    systemctl enable --quiet --now pve-ha-lrm 2>/dev/null || { msg_error "Failed to enable pve-ha-lrm"; return 1; }
    systemctl enable --quiet --now pve-ha-crm 2>/dev/null || { msg_error "Failed to enable pve-ha-crm"; return 1; }
    systemctl enable --quiet --now corosync 2>/dev/null || { msg_error "Failed to enable corosync"; return 1; }
    
    msg_ok "Enabled High Availability services"
    log_message "INFO" "HA services (pve-ha-lrm, pve-ha-crm, corosync) enabled"
}

# Disable High Availability services
disable_ha_services() {
    msg_info "Disabling High Availability services"
    
    systemctl disable --quiet --now pve-ha-lrm 2>/dev/null || true
    systemctl disable --quiet --now pve-ha-crm 2>/dev/null || true
    
    # Ask about corosync separately as it's cluster communication
    if whiptail --yesno "Also disable Corosync (cluster communication)?\n\nOnly disable if this is a standalone node." 10 60; then
        systemctl disable --quiet --now corosync 2>/dev/null || true
        msg_ok "Disabled High Availability services (including Corosync)"
        log_message "INFO" "All HA services disabled including Corosync"
    else
        msg_ok "Disabled High Availability services (Corosync kept running)"
        log_message "INFO" "HA services disabled, Corosync kept running"
    fi
}

# Manage High Availability services
manage_ha_services() {
    if is_ha_active; then
        # HA is currently active
        local choice
        choice=$(whiptail --title "High Availability Management" \
            --menu "HA services are currently RUNNING.\n\nFor single-node setups, you can disable HA services to save system resources.\n\nWhat would you like to do?" 16 70 3 \
            "keep" "Keep HA services running" \
            "disable" "Disable HA services (single node)" \
            "cancel" "Cancel" 3>&2 2>&1 1>&3)
        
        case "$choice" in
            keep)
                msg_ok "High Availability services kept running"
                ;;
            disable)
                if whiptail --yesno "Are you sure you want to disable HA services?\n\nThis is recommended for single-node setups but should NOT be done on clustered systems." 10 60; then
                    disable_ha_services
                fi
                ;;
            cancel|"")
                return 0
                ;;
        esac
    else
        # HA is not active
        local choice
        choice=$(whiptail --title "High Availability Management" \
            --menu "HA services are currently STOPPED.\n\nWhat would you like to do?" 12 60 3 \
            "enable" "Enable HA services" \
            "keep" "Keep HA services disabled" \
            "cancel" "Cancel" 3>&2 2>&1 1>&3)
        
        case "$choice" in
            enable)
                if whiptail --yesno "Enable High Availability services?\n\nThis is needed for clustered environments." 8 60; then
                    enable_ha_services
                fi
                ;;
            keep)
                msg_ok "High Availability services kept disabled"
                ;;
            cancel|"")
                return 0
                ;;
        esac
    fi
}

# Show setup guide information
show_setup_guide() {
    whiptail --title "Proxmox VE 9 Setup Guide" --msgbox \
"📖 COMPLETE SETUP GUIDE AVAILABLE

For detailed step-by-step instructions, best practices, and additional configuration options, visit our comprehensive setup guide:

🔗 GitHub Repository:
https://tinyurl.com/ymwf48z2

This guide covers:
• Pre-installation planning
• Post-installation hardening
• Network configuration
• Storage optimization
• Security best practices
• VM/Container setup
• Backup strategies
• Troubleshooting tips

The guide is regularly updated with the latest information and community feedback." 18 75
}

# Main menu
show_main_menu() {
    while true; do
        local choice
        choice=$(whiptail --title "$SCRIPT_NAME v$SCRIPT_VERSION - PVE 9 Only" --menu "Select an option:" 22 80 12 \
            "1" "Configure repositories and update system" \
            "2" "Install useful dependencies" \
            "3" "Install Bennell IT subscription bypass" \
            "4" "Add Bennell IT login banner" \
            "5" "Add Bennell IT SSH key" \
            "6" "Setup SMTP configuration" \
            "7" "Disable subscription nag message" \
            "8" "Manage High Availability services" \
            "9" "Show system information" \
            "G" "View setup guide information" \
            "U" "Update system packages only" \
            "R" "Reboot system" \
            "0" "Exit" 3>&2 2>&1 1>&3)
        
        case "$choice" in
            1) configure_repositories && whiptail --msgbox "Repositories configured and system updated successfully" 8 60 ;;
            2) install_dependencies && whiptail --msgbox "Dependencies installed successfully" 8 50 ;;
            3) install_subscription_bypass && whiptail --msgbox "Subscription bypass processed" 8 50 ;;
            4) add_login_banner && whiptail --msgbox "Login banner processed" 8 50 ;;
            5) add_ssh_key && whiptail --msgbox "SSH key processed" 8 50 ;;
            6) setup_smtp && whiptail --msgbox "SMTP setup completed" 8 50 ;;
            7) disable_subscription_nag && whiptail --msgbox "Subscription nag processed" 8 50 ;;
            8) manage_ha_services && whiptail --msgbox "High Availability management completed" 8 60 ;;
            9) show_system_info ;;
            G) show_setup_guide ;;
            U) system_update && whiptail --msgbox "System updated successfully" 8 50 ;;
            R) reboot_system ;;
            0|"") exit 0 ;;
            *) whiptail --msgbox "Invalid option selected" 8 40 ;;
        esac
    done
}

# Reboot with comprehensive final warnings
show_system_info() {
    local pve_version
    pve_version="$(get_pve_version)"
    
    local info="System Information:\n\n"
    info+="Hostname: $HOSTNAME\n"
    info+="System Type: Proxmox VE\n"
    info+="Proxmox VE Version: $pve_version\n"
    
    # Show HA service status
    if is_ha_active; then
        info+="High Availability: ENABLED\n"
    else
        info+="High Availability: DISABLED\n"
    fi
    
    info+="Timestamp: $TIMESTAMP\n"
    info+="Log File: $LOG_FILE\n"
    info+="Config Directory: $CONFIG_DIR\n"
    
    whiptail --msgbox "$info" 15 60
}

# Reboot with comprehensive final warnings
reboot_system() {
    if whiptail --yesno "Are you sure you want to reboot the system now?" 8 50; then
        msg_info "Rebooting system"
        log_message "INFO" "System reboot initiated by user"
        
        # Final reminder
        whiptail --title "🔄 Rebooting..." --msgbox \
"System is rebooting now.

REMEMBER: Clear your browser cache (Ctrl+Shift+R) after the system comes back online!" 8 60
        
        sleep 2
        reboot
    fi
}

# Main execution
main() {
    # Initialize logging
    touch "$LOG_FILE"
    log_message "INFO" "Script started: $SCRIPT_NAME v$SCRIPT_VERSION (PVE 9 Only)"
    
    # Check prerequisites
    check_root
    
    # Display header
    display_header
    
    # Perform first run setup
    first_run_setup
    
    # Show main menu
    show_main_menu
    
    log_message "INFO" "Script completed successfully"
}

# Run main function
main "$@"
