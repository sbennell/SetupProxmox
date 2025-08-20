#!/usr/bin/env bash
set -euo pipefail

# Script configuration
readonly SCRIPT_NAME="Proxmox Post Install Script"
readonly SCRIPT_VERSION="3.0"
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

# Check if component exists in deb822 sources
component_exists_in_sources() {
    local component="$1"
    grep -h -E "^[^#]*Components:[^#]*\\b${component}\\b" /etc/apt/sources.list.d/*.sources 2>/dev/null | grep -q .
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
    local pve_version pve_major pve_minor system_type
    system_type=$(detect_system_type)
    
    if [[ "$system_type" == "pve" ]]; then
        pve_version="$(get_pve_version)"
        read -r pve_major pve_minor <<<"$(get_pve_major_minor "$pve_version")"
        log_message "INFO" "Detected Proxmox VE $pve_version (system type: $system_type)"
        echo "$pve_major.$pve_minor" > "$CONFIG_DIR/pve_version"
    elif [[ "$system_type" == "pbs" ]]; then
        log_message "INFO" "Detected Proxmox Backup Server"
        echo "pbs" > "$CONFIG_DIR/pve_version"
    else
        msg_error "Unknown system type detected"
        return 1
    fi
    
    # Mark first run as complete
    echo "true" > "$FIRST_RUN_MARKER"
    msg_ok "First run setup completed"
}

# Configure repositories for Proxmox VE 8.x
configure_pve8_repositories() {
    local distribution
    distribution=$(. /etc/*-release; echo "$VERSION_CODENAME")
    
    msg_info "Configuring Proxmox VE 8.x repositories"
    
    # Configure main Debian sources
    if whiptail --yesno "Configure correct Debian Bookworm sources?" 8 60; then
        backup_file "/etc/apt/sources.list"
        cat > /etc/apt/sources.list << EOF
deb http://deb.debian.org/debian bookworm main contrib
deb http://deb.debian.org/debian bookworm-updates main contrib
deb http://security.debian.org/debian-security bookworm-security main contrib
EOF
        echo 'APT::Get::Update::SourceListWarnings::NonFreeFirmware "false";' > /etc/apt/apt.conf.d/no-bookworm-firmware.conf
        msg_ok "Configured Debian Bookworm sources"
    fi
    
    # Disable enterprise repository
    if whiptail --yesno "Disable PVE enterprise repository?" 8 60; then
        backup_file "/etc/apt/sources.list.d/pve-enterprise.list"
        cat > /etc/apt/sources.list.d/pve-enterprise.list << EOF
# deb https://enterprise.proxmox.com/debian/pve bookworm pve-enterprise
EOF
        msg_ok "Disabled PVE enterprise repository"
    fi
    
    # Enable no-subscription repository
    if whiptail --yesno "Enable PVE no-subscription repository?" 8 60; then
        cat > /etc/apt/sources.list.d/pve-install-repo.list << EOF
deb http://download.proxmox.com/debian/pve bookworm pve-no-subscription
EOF
        msg_ok "Enabled PVE no-subscription repository"
    fi
    
    # Configure Ceph repositories
    if whiptail --yesno "Configure Ceph package repositories?" 8 60; then
        backup_file "/etc/apt/sources.list.d/ceph.list"
        cat > /etc/apt/sources.list.d/ceph.list << EOF
# deb https://enterprise.proxmox.com/debian/ceph-quincy bookworm enterprise
# deb http://download.proxmox.com/debian/ceph-quincy bookworm no-subscription
# deb https://enterprise.proxmox.com/debian/ceph-reef bookworm enterprise
# deb http://download.proxmox.com/debian/ceph-reef bookworm no-subscription
EOF
        msg_ok "Configured Ceph package repositories"
    fi
    
    # Add test repository (disabled)
    if whiptail --yesno "Add PVE test repository (disabled)?" 8 60; then
        cat > /etc/apt/sources.list.d/pvetest-for-beta.list << EOF
# deb http://download.proxmox.com/debian/pve bookworm pvetest
EOF
        msg_ok "Added PVE test repository (disabled)"
    fi
}

# Configure repositories for Proxmox VE 9.x (deb822 format)
configure_pve9_repositories() {
    msg_info "Configuring Proxmox VE 9.x repositories (deb822 format)"
    
    # Check and handle legacy sources
    check_and_disable_legacy_sources() {
        local legacy_count=0
        local listfile="/etc/apt/sources.list"
        local list_files
        
        # Check sources.list
        if [[ -f "$listfile" ]] && grep -qE '^\s*deb ' "$listfile"; then
            ((legacy_count++))
        fi
        
        # Check .list files
        list_files=$(find /etc/apt/sources.list.d/ -type f -name "*.list" 2>/dev/null || true)
        if [[ -n "$list_files" ]]; then
            legacy_count=$((legacy_count + $(echo "$list_files" | wc -l)))
        fi
        
        if ((legacy_count > 0)); then
            local msg="Legacy APT sources found:\n"
            [[ -f "$listfile" ]] && msg+=" - /etc/apt/sources.list\n"
            [[ -n "$list_files" ]] && msg+="$(echo "$list_files" | sed 's|^| - |')\n"
            msg+="\nDisable legacy sources and use deb822 format?"
            
            if whiptail --yesno "$msg" 15 80; then
                # Backup and disable sources.list
                if [[ -f "$listfile" ]] && grep -qE '^\s*deb ' "$listfile"; then
                    backup_file "$listfile"
                    sed -i '/^\s*deb /s/^/# Disabled by Proxmox Helper Script /' "$listfile"
                    msg_ok "Disabled entries in sources.list"
                fi
                # Rename all .list files to .list.bak
                if [[ -n "$list_files" ]]; then
                    while IFS= read -r f; do
                        [[ -f "$f" ]] && mv "$f" "$f.bak"
                    done <<<"$list_files"
                    msg_ok "Renamed legacy .list files to .bak"
                fi
            fi
        fi
    }
    
    # Check if deb822 sources exist
    if ! find /etc/apt/sources.list.d/ -maxdepth 1 -name '*.sources' | grep -q .; then
        check_and_disable_legacy_sources
    fi
    
    # Configure main Debian sources (deb822)
    if whiptail --yesno "Configure Debian Trixie sources (deb822 format)?" 8 60; then
        cat > /etc/apt/sources.list.d/debian.sources << 'EOF'
Types: deb
URIs: http://deb.debian.org/debian
Suites: trixie
Components: main contrib
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb
URIs: http://security.debian.org/debian-security
Suites: trixie-security
Components: main contrib
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb
URIs: http://deb.debian.org/debian
Suites: trixie-updates
Components: main contrib
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF
        msg_ok "Configured Debian Trixie sources (deb822)"
    fi
    
    # Handle PVE enterprise repository
    if component_exists_in_sources "pve-enterprise"; then
        if whiptail --yesno "PVE enterprise repository exists. Disable it?" 8 60; then
            for file in /etc/apt/sources.list.d/*.sources; do
                if grep -q "Components:.*pve-enterprise" "$file" 2>/dev/null; then
                    backup_file "$file"
                    sed -i '/^\s*Types:/,/^$/s/^\([^#].*\)$/# \1/' "$file"
                fi
            done
            msg_ok "Disabled PVE enterprise repository"
        fi
    fi
    
    # Add PVE no-subscription repository
    if ! component_exists_in_sources "pve-no-subscription"; then
        if whiptail --yesno "Add PVE no-subscription repository?" 8 60; then
            cat > /etc/apt/sources.list.d/proxmox.sources << 'EOF'
Types: deb
URIs: http://download.proxmox.com/debian/pve
Suites: trixie
Components: pve-no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
EOF
            msg_ok "Added PVE no-subscription repository"
        fi
    else
        msg_ok "PVE no-subscription repository already exists"
    fi
    
    # Add Ceph repository
    if ! component_exists_in_sources "no-subscription" && whiptail --yesno "Add Ceph package repository?" 8 60; then
        cat > /etc/apt/sources.list.d/ceph.sources << 'EOF'
Types: deb
URIs: http://download.proxmox.com/debian/ceph-squid
Suites: trixie
Components: no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
EOF
        msg_ok "Added Ceph package repository"
    fi
    
    # Add test repository (disabled)
    if ! component_exists_in_sources "pve-test" && whiptail --yesno "Add PVE test repository (disabled)?" 8 60; then
        cat > /etc/apt/sources.list.d/pve-test.sources << 'EOF'
# Types: deb
# URIs: http://download.proxmox.com/debian/pve
# Suites: trixie
# Components: pve-test
# Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
EOF
        msg_ok "Added PVE test repository (disabled)"
    fi
}

# Configure PBS repositories
configure_pbs_repositories() {
    local distribution
    distribution=$(. /etc/*-release; echo "$VERSION_CODENAME")
    
    msg_info "Configuring PBS repositories"
    
    # Add PBS no-subscription repository
    local sources_file="/etc/apt/sources.list"
    backup_file "$sources_file"
    
    if ! grep -q "download.proxmox.com/debian/pbs.*pbs-no-subscription" "$sources_file"; then
        echo "deb http://download.proxmox.com/debian/pbs $distribution pbs-no-subscription" >> "$sources_file"
        log_message "INFO" "Added PBS no-subscription repository"
    fi
    
    # Disable enterprise repository
    local enterprise_file="/etc/apt/sources.list.d/pbs-enterprise.list"
    if [[ -f "$enterprise_file" ]]; then
        backup_file "$enterprise_file"
        if ! grep -q "^#.*enterprise.proxmox.com" "$enterprise_file"; then
            sed -i 's/^deb/#deb/' "$enterprise_file"
            log_message "INFO" "Commented out PBS enterprise repository"
        fi
    fi
    
    msg_ok "PBS repositories configured"
}

# System update
system_update() {
    msg_info "Updating system packages"
    apt-get update -y -qq || { msg_error "apt update failed"; return 1; }
    apt-get upgrade -y -qq || { msg_error "apt upgrade failed"; return 1; }
    apt-get dist-upgrade -y -qq || { msg_error "apt dist-upgrade failed"; return 1; }
    msg_ok "System updated successfully"
}

# Configure repositories based on version
configure_repositories() {
    local system_type pve_major pve_minor
    system_type=$(detect_system_type)
    
    # Show educational information first
    show_educational_info "repositories"
    
    if [[ "$system_type" == "pve" ]]; then
        local pve_version
        pve_version="$(get_pve_version)"
        read -r pve_major pve_minor <<<"$(get_pve_major_minor "$pve_version")"
        
        log_message "INFO" "Detected Proxmox VE $pve_version"
        
        if [[ "$pve_major" == "8" ]]; then
            configure_pve8_repositories
        elif [[ "$pve_major" == "9" ]]; then
            configure_pve9_repositories
        else
            msg_error "Unsupported Proxmox VE version: $pve_major.$pve_minor"
            return 1
        fi
    elif [[ "$system_type" == "pbs" ]]; then
        configure_pbs_repositories
    else
        msg_error "Unsupported system type: $system_type"
        return 1
    fi
    
    system_update
    
    # Show cluster warning and browser cache info
    show_educational_info "cluster_warning"
    show_educational_info "browser_cache"
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
    # Show comprehensive educational warning first
    show_educational_info "subscription_bypass"
    
    msg_info "Installing Bennell IT subscription bypass"
    
    # Additional warning dialog
    if ! whiptail --yesno "After reading the information above, do you still wish to proceed with the subscription bypass installation?" 8 70; then
        msg_ok "Subscription bypass installation cancelled by user"
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

# Add SSH key with comprehensive security education
add_ssh_key() {
    # Show comprehensive security education first
    show_educational_info "ssh_key"
    
    msg_info "Adding Bennell IT SSH key"
    
    # Additional security confirmation
    if ! whiptail --yesno "After understanding the security implications above, do you want to add the Bennell IT SSH key?" 8 70; then
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

# Educational messages and warnings
show_educational_info() {
    local topic="$1"
    
    case "$topic" in
        repositories)
            whiptail --title "Repository Information" --msgbox \
"REPOSITORY CONFIGURATION EXPLANATION:

Enterprise Repository:
• Requires paid Proxmox subscription
• Provides stable, tested updates
• Includes commercial support

No-Subscription Repository:  
• Free community repository
• Same packages as enterprise
• No commercial support
• Perfectly suitable for home/test use

Test Repository:
• Early access to new features
• May contain unstable packages
• Only for advanced users/testing
• Should remain DISABLED unless needed

WARNING: After repository changes, you MUST:
1. Clear your browser cache (Ctrl+Shift+R)
2. Reboot the system for full effect" 20 75
            ;;
        subscription_bypass)
            whiptail --title "Subscription Bypass Warning" --msgbox \
"⚠️  IMPORTANT LEGAL AND ETHICAL NOTICE ⚠️

Installing a subscription bypass:

LEGAL CONSIDERATIONS:
• May violate Proxmox VE license terms
• Could void any existing support agreements
• Use at your own risk and responsibility

ALTERNATIVE RECOMMENDATIONS:
• Consider purchasing a Proxmox subscription
• Supports the developers who create this software
• Provides access to enterprise repository
• Includes professional support

COMMUNITY SUPPORT:
• The no-subscription repository is FREE
• Provides the same software functionality
• Perfect for home labs and learning
• No bypass needed for basic usage

Continue only if you understand these implications." 22 75
            ;;
        ssh_key)
            whiptail --title "SSH Key Security Warning" --msgbox \
"🔐 SSH KEY SECURITY IMPLICATIONS:

What this does:
• Adds Bennell IT's public SSH key to root account
• Allows passwordless SSH access as root
• Provides remote administrative access

SECURITY RISKS:
• Third-party access to your system
• Potential unauthorized access
• Key owner has full system control

RECOMMENDATIONS:
• Only proceed if you trust Bennell IT completely
• Consider creating a separate user account instead
• Regularly audit authorized_keys file
• Monitor system logs for unexpected access

ALTERNATIVES:
• Set up your own SSH keys
• Use strong passwords with SSH
• Configure fail2ban for brute force protection

Think carefully before proceeding!" 22 70
            ;;
        ha_services)
            whiptail --title "High Availability Information" --msgbox \
"📊 HIGH AVAILABILITY SERVICE GUIDE:

What are HA Services?
• pve-ha-lrm: Local Resource Manager
• pve-ha-crm: Cluster Resource Manager  
• corosync: Cluster communication

WHEN TO ENABLE:
✅ Multi-node Proxmox clusters
✅ Production environments
✅ Need VM/CT failover capability
✅ Planning to add nodes later

WHEN TO DISABLE:
✅ Single-node installations
✅ Home labs and testing
✅ Resource-constrained systems
✅ Maximum VM performance needed

RESOURCE SAVINGS (single node):
• ~50-100MB RAM reduction
• Lower CPU overhead
• Reduced network traffic
• Less disk I/O

You can always re-enable later if needed!" 22 70
            ;;
        cluster_warning)
            whiptail --title "⚠️ CLUSTER ENVIRONMENT WARNING" --msgbox \
"🏢 IMPORTANT FOR CLUSTERED ENVIRONMENTS:

If you have MULTIPLE Proxmox nodes in a cluster:

CRITICAL REQUIREMENTS:
• Run this script on EVERY cluster node individually
• Do NOT run on just one node
• Ensure consistent configuration across all nodes
• Repository changes must match on all nodes

FAILURE TO DO THIS CAN CAUSE:
• Cluster instability
• Package version mismatches  
• Update failures
• Service disruptions

RECOMMENDED PROCEDURE:
1. Start with one node (maintenance mode)
2. Test changes thoroughly
3. Apply same changes to other nodes
4. Verify cluster health after each node

This script does NOT automatically configure other cluster nodes!" 20 75
            ;;
        browser_cache)
            whiptail --title "🌐 Browser Cache Warning" --msgbox \
"CRITICAL: CLEAR BROWSER CACHE

After making changes to Proxmox, you MUST clear your browser cache!

WHY THIS MATTERS:
• Proxmox web UI caches JavaScript files
• Old cached files cause display issues
• Subscription nag may persist in cache
• Interface elements may not work correctly

HOW TO CLEAR CACHE:

Chrome/Firefox:
• Press Ctrl+Shift+R (hard reload)
• Or Ctrl+F5 (force refresh)
• Or manually clear browser cache

Alternative:
• Open private/incognito window
• Use different browser temporarily
• Clear all browsing data

SYMPTOMS OF CACHE ISSUES:
• Subscription nag still appears
• Interface looks broken/old
• JavaScript errors in console
• Features not working properly

Don't skip this step!" 22 70
            ;;
        post_install_checklist)
            whiptail --title "📋 Post-Installation Checklist" --msgbox \
"IMPORTANT STEPS AFTER RUNNING THIS SCRIPT:

IMMEDIATE ACTIONS:
□ Clear browser cache (Ctrl+Shift+R)
□ Reboot the system (recommended)
□ Test web interface functionality

CLUSTER ENVIRONMENTS:
□ Run script on ALL cluster nodes
□ Verify cluster status: pvecm status
□ Check node communication
□ Test VM migration (if applicable)

SECURITY REVIEW:
□ Review SSH authorized_keys
□ Check firewall settings
□ Verify user accounts
□ Monitor system logs

ONGOING MAINTENANCE:
□ Regular system updates
□ Monitor system resources
□ Backup configurations
□ Document any customizations

SUPPORT REMINDER:
Consider supporting Proxmox development by purchasing a subscription. It helps ensure continued development of this excellent platform." 22 75
            ;;
    esac
}
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
    local system_type
    system_type=$(detect_system_type)
    
    if [[ "$system_type" != "pve" ]]; then
        whiptail --msgbox "High Availability management is only available for Proxmox VE hosts" 8 60
        return 1
    fi
    
    # Show educational information first
    show_educational_info "ha_services"
    
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

# Main menu
show_main_menu() {
    while true; do
        local choice
        choice=$(whiptail --title "$SCRIPT_NAME v$SCRIPT_VERSION" --menu "Select an option:" 24 80 14 \
            "1" "Configure repositories and update system" \
            "2" "Install useful dependencies" \
            "3" "Install Bennell IT subscription bypass" \
            "4" "Add Bennell IT login banner (PVE only)" \
            "5" "Add Bennell IT SSH key" \
            "6" "Setup SMTP configuration" \
            "7" "Disable subscription nag message" \
            "8" "Manage High Availability services" \
            "9" "Show system information" \
            "I" "Show educational information menu" \
            "C" "Show post-install checklist" \
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
            I) show_info_menu ;;
            C) show_educational_info "post_install_checklist" ;;
            U) system_update && whiptail --msgbox "System updated successfully" 8 50 ;;
            R) reboot_system ;;
            0|"") exit 0 ;;
            *) whiptail --msgbox "Invalid option selected" 8 40 ;;
        esac
    done
}

# Educational information menu
show_info_menu() {
    local choice
    choice=$(whiptail --title "📚 Educational Information" --menu "Select a topic to learn about:" 18 70 8 \
        "repo" "Repository configuration explained" \
        "bypass" "Subscription bypass implications" \
        "ssh" "SSH key security considerations" \
        "ha" "High Availability services guide" \
        "cluster" "Cluster environment warnings" \
        "cache" "Browser cache importance" \
        "checklist" "Post-install checklist" \
        "back" "Return to main menu" 3>&2 2>&1 1>&3)
    
    case "$choice" in
        repo) show_educational_info "repositories" ;;
        bypass) show_educational_info "subscription_bypass" ;;
        ssh) show_educational_info "ssh_key" ;;
        ha) show_educational_info "ha_services" ;;
        cluster) show_educational_info "cluster_warning" ;;
        cache) show_educational_info "browser_cache" ;;
        checklist) show_educational_info "post_install_checklist" ;;
        back|"") return 0 ;;
    esac
}

# Show system information
show_system_info() {
    local system_type pve_version
    system_type=$(detect_system_type)
    
    local info="System Information:\n\n"
    info+="Hostname: $HOSTNAME\n"
    info+="System Type: $system_type\n"
    
    if [[ "$system_type" == "pve" ]]; then
        pve_version="$(get_pve_version)"
        info+="Proxmox VE Version: $pve_version\n"
        
        # Show HA service status
        if is_ha_active; then
            info+="High Availability: ENABLED\n"
        else
            info+="High Availability: DISABLED\n"
        fi
    fi
    
    info+="Timestamp: $TIMESTAMP\n"
    info+="Log File: $LOG_FILE\n"
    info+="Config Directory: $CONFIG_DIR\n"
    
    whiptail --msgbox "$info" 15 60
}

# Reboot with comprehensive final warnings
reboot_system() {
    # Show final checklist before reboot
    whiptail --title "🔄 Pre-Reboot Checklist" --msgbox \
"BEFORE REBOOTING, PLEASE VERIFY:

CLUSTER ENVIRONMENTS:
□ If you have multiple nodes, run this script on ALL nodes
□ Check cluster status is healthy
□ Ensure no running migrations or backups

BROWSER PREPARATION:
□ Clear browser cache after reboot (Ctrl+Shift+R)  
□ Or use private/incognito window
□ Have login credentials ready

POST-REBOOT TASKS:
□ Test Proxmox web interface
□ Verify all services are running
□ Check system logs for any errors
□ Test VM/CT functionality

The reboot helps ensure all changes take effect properly." 20 65

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
