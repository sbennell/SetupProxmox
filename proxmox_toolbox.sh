#!/usr/bin/env bash
set -euo pipefail

# Script configuration
readonly SCRIPT_NAME="Proxmox Post Install Script"
readonly SCRIPT_VERSION="2.0"
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

# System detection
readonly DISTRIBUTION=$(. /etc/*-release; echo "$VERSION_CODENAME")
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
    echo -e "${BFR} ${COLOR_RED}✗ ${msg}${COLOR_CLEAR}"
    log_message "ERROR" "$msg"
}

# Detect system type
detect_system_type() {
    if [[ -d "$PVE_LOG_FOLDER" ]]; then
        echo "pve"
    elif [[ -f /usr/bin/proxmox-backup-manager ]]; then
        echo "pbs"
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

# Improved first run function
first_run_setup() {
    if [[ -f "$FIRST_RUN_MARKER" ]]; then
        return 0
    fi
    
    msg_info "Performing first run setup"
    
    # Create necessary directories
    mkdir -p "$CONFIG_DIR" "$ENABLE_DIR"
    
    local system_type
    system_type=$(detect_system_type)
    
    case "$system_type" in
        pve)
            log_message "INFO" "Detected Proxmox VE host"
            configure_pve_repositories
            ;;
        pbs)
            log_message "INFO" "Detected Proxmox Backup Server host"
            configure_pbs_repositories
            ;;
        *)
            msg_error "Unknown system type detected"
            return 1
            ;;
    esac
    
    # Mark first run as complete
    echo "true" > "$FIRST_RUN_MARKER"
    msg_ok "First run setup completed"
}

# Configure PVE repositories
configure_pve_repositories() {
    local enterprise_file="/etc/apt/sources.list.d/pve-enterprise.list"
    local ceph_file="/etc/apt/sources.list.d/ceph.list"
    
    # Comment out enterprise repositories
    if [[ -f "$enterprise_file" ]]; then
        backup_file "$enterprise_file"
        if ! grep -q "^#.*enterprise.proxmox.com" "$enterprise_file"; then
            sed -i 's/^deb/#deb/' "$enterprise_file"
            log_message "INFO" "Commented out PVE enterprise repository"
        fi
    fi
    
    if [[ -f "$ceph_file" ]]; then
        backup_file "$ceph_file"
        if ! grep -q "^#.*enterprise.proxmox.com" "$ceph_file"; then
            sed -i 's/^deb/#deb/' "$ceph_file"
            log_message "INFO" "Commented out Ceph enterprise repository"
        fi
    fi
}

# Configure PBS repositories
configure_pbs_repositories() {
    local enterprise_file="/etc/apt/sources.list.d/pbs-enterprise.list"
    
    if [[ -f "$enterprise_file" ]]; then
        backup_file "$enterprise_file"
        if ! grep -q "^#.*enterprise.proxmox.com" "$enterprise_file"; then
            sed -i 's/^deb/#deb/' "$enterprise_file"
            log_message "INFO" "Commented out PBS enterprise repository"
        fi
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

# Improved update function
system_update() {
    # Check if custom update script exists
    if [[ ! -f /usr/bin/proxmox-update ]]; then
        msg_info "Installing proxmox-update script"
        if download_file "https://raw.githubusercontent.com/sbennell/SetupProxmox/master/files/proxmox-update" "/usr/bin/proxmox-update"; then
            chmod +x /usr/bin/proxmox-update
            msg_ok "proxmox-update script installed"
        else
            msg_error "Failed to install proxmox-update script"
        fi
    fi
    
    msg_info "Updating system packages"
    apt-get update -y -qq
    apt-get upgrade -y -qq
    apt-get dist-upgrade -y -qq
    msg_ok "System updated successfully"
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

# Configure no-enterprise repositories
configure_no_enterprise_repos() {
    msg_info "Configuring no-enterprise repositories"
    
    local system_type
    system_type=$(detect_system_type)
    local sources_file="/etc/apt/sources.list"
    
    backup_file "$sources_file"
    
    case "$system_type" in
        pve)
            # Add PVE no-subscription repository
            if ! grep -q "download.proxmox.com/debian/pve.*pve-no-subscription" "$sources_file"; then
                echo "deb http://download.proxmox.com/debian/pve $DISTRIBUTION pve-no-subscription" >> "$sources_file"
                log_message "INFO" "Added PVE no-subscription repository"
            fi
            
            # Add non-free-firmware repository
            if ! grep -q "ftp.debian.org/debian.*non-free-firmware" "$sources_file"; then
                echo "deb http://ftp.debian.org/debian $DISTRIBUTION main contrib non-free-firmware" >> "$sources_file"
                log_message "INFO" "Added non-free-firmware repository"
            fi
            
            configure_pve_repositories
            ;;
            
        pbs)
            # Add PBS no-subscription repository
            if ! grep -q "download.proxmox.com/debian/pbs.*pbs-no-subscription" "$sources_file"; then
                echo "deb http://download.proxmox.com/debian/pbs $DISTRIBUTION pbs-no-subscription" >> "$sources_file"
                log_message "INFO" "Added PBS no-subscription repository"
            fi
            
            configure_pbs_repositories
            ;;
            
        *)
            msg_error "Unsupported system type: $system_type"
            return 1
            ;;
    esac
    
    system_update
    msg_ok "No-enterprise repositories configured"
}

# Add test repositories (disabled)
add_test_repositories() {
    msg_info "Adding test repositories (disabled)"
    
    local system_type
    system_type=$(detect_system_type)
    local sources_file="/etc/apt/sources.list"
    
    backup_file "$sources_file"
    
    case "$system_type" in
        pve)
            if ! grep -q "pvetest" "$sources_file"; then
                echo "#deb http://download.proxmox.com/debian/pve $DISTRIBUTION pvetest" >> "$sources_file"
                log_message "INFO" "Added PVE test repository (disabled)"
            fi
            ;;
            
        pbs)
            if ! grep -q "pbstest" "$sources_file"; then
                echo "#deb http://download.proxmox.com/debian/pbs $DISTRIBUTION pbstest" >> "$sources_file"
                log_message "INFO" "Added PBS test repository (disabled)"
            fi
            ;;
    esac
    
    msg_ok "Test repositories added (disabled)"
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

# Install subscription bypass (with warning)
install_subscription_bypass() {
    msg_info "Installing Bennell IT subscription bypass"
    
    # Warning about potential licensing issues
    if ! whiptail --yesno "WARNING: This will install a subscription bypass that may violate Proxmox licensing terms. Continue?" 10 60; then
        return 0
    fi
    
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

# Add login banner (PVE only)
add_login_banner() {
    local system_type
    system_type=$(detect_system_type)
    
    if [[ "$system_type" != "pve" ]]; then
        whiptail --msgbox "Login banner is only available for PVE hosts" 8 50
        return 1
    fi
    
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

# Add SSH key with confirmation
add_ssh_key() {
    msg_info "Adding Bennell IT SSH key"
    
    # Warning about security implications
    if ! whiptail --yesno "WARNING: This will add a Bennell IT SSH key to root's authorized_keys. This allows remote access. Continue?" 10 60; then
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

# Main menu
show_main_menu() {
    while true; do
        local choice
        choice=$(whiptail --title "$SCRIPT_NAME v$SCRIPT_VERSION" --menu "Select an option:" 18 80 10 \
            "1" "Configure no-enterprise repositories and update" \
            "2" "Add test/beta repositories (disabled)" \
            "3" "Install useful dependencies" \
            "4" "Install Bennell IT subscription bypass" \
            "5" "Add Bennell IT login banner (PVE only)" \
            "6" "Add Bennell IT SSH key" \
            "7" "Setup SMTP configuration" \
            "8" "Show system information" \
            "9" "Reboot system" \
            "0" "Exit" 3>&2 2>&1 1>&3)
        
        case "$choice" in
            1) configure_no_enterprise_repos && whiptail --msgbox "No-enterprise repositories configured successfully" 8 50 ;;
            2) add_test_repositories && whiptail --msgbox "Test repositories added (disabled)" 8 50 ;;
            3) install_dependencies && whiptail --msgbox "Dependencies installed successfully" 8 50 ;;
            4) install_subscription_bypass && whiptail --msgbox "Subscription bypass installed" 8 50 ;;
            5) add_login_banner && whiptail --msgbox "Login banner added successfully" 8 50 ;;
            6) add_ssh_key && whiptail --msgbox "SSH key added successfully" 8 50 ;;
            7) setup_smtp && whiptail --msgbox "SMTP setup completed" 8 50 ;;
            8) show_system_info ;;
            9) reboot_system ;;
            0|"") exit 0 ;;
            *) whiptail --msgbox "Invalid option selected" 8 40 ;;
        esac
    done
}

# Show system information
show_system_info() {
    local system_type
    system_type=$(detect_system_type)
    
    local info="System Information:\n\n"
    info+="Hostname: $HOSTNAME\n"
    info+="Distribution: $DISTRIBUTION\n"
    info+="System Type: $system_type\n"
    info+="Timestamp: $TIMESTAMP\n"
    info+="Log File: $LOG_FILE\n"
    
    whiptail --msgbox "$info" 15 60
}

# Reboot with confirmation
reboot_system() {
    if whiptail --yesno "Are you sure you want to reboot the system?" 8 50; then
        msg_info "Rebooting system"
        log_message "INFO" "System reboot initiated by user"
        reboot
    fi
}

# Main execution
main() {
    # Initialize logging
    touch "$LOG_FILE"
    log_message "INFO" "Script started: $SCRIPT_NAME v$SCRIPT_VERSION"
    
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
