# SetupProxmox

A comprehensive post-installation script for Proxmox VE that configures repositories, removes subscription dialogs, installs useful tools, and provides optional system enhancements.

## Features

- **Repository Management**: Automatically configures correct repositories for PVE 8.x and 9.x
  - Disables enterprise repositories (requires paid subscription)
  - Enables no-subscription repositories (free community repos)
  - Supports both legacy and modern deb822 format
- **System Updates**: Performs apt update, upgrade, and dist-upgrade
- **Subscription Nag Removal**: Optionally removes subscription warning dialogs
- **Useful Dependencies**: Installs commonly needed packages (git, curl, sudo, etc.)
- **SMTP Configuration**: Sets up Postfix for Office365 SMTP relay
- **High Availability Management**: Enable/disable HA services for single-node setups
- **Educational Warnings**: Comprehensive information about security and legal implications

## Compatibility

- **Proxmox VE 8.x**: Tested up to 8.2.x (Debian Bookworm)
- **Proxmox VE 9.x**: Full support including deb822 repository format (Debian Trixie)
- **Proxmox Backup Server**: Basic repository configuration support

## Installation

### Quick Install
Connect to your Proxmox node via SSH and run:

```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/sbennell/SetupProxmox/master/proxmox_toolbox.sh)"

bash -c "$(wget -qLO - https://raw.githubusercontent.com/sbennell/SetupProxmox/master/proxmox_PVE_9_toolbox.sh)"


```

### Manual Download
```bash
wget https://raw.githubusercontent.com/sbennell/SetupProxmox/master/proxmox_toolbox.sh
chmod +x proxmox_toolbox.sh
./proxmox_toolbox.sh
```

## Important Security Notices

### SSH Key Installation
The script optionally adds Bennell IT's SSH key for remote access. **This provides third-party access to your system.** Only proceed if you:
- Completely trust Bennell IT
- Understand the security implications
- Are comfortable with remote administrative access

### Subscription Bypass
The subscription bypass feature:
- May violate Proxmox VE license terms
- Could void support agreements
- Should only be used for non-commercial purposes
- Consider purchasing a legitimate subscription instead

## Post-Installation Steps

### Critical Actions Required
1. **Clear Browser Cache**: Press `Ctrl+Shift+R` or use private/incognito mode
2. **Reboot System**: Recommended to ensure all changes take effect
3. **Test Web Interface**: Verify Proxmox web UI functionality

### Cluster Environments
If you have multiple Proxmox nodes:
- Run the script on **every cluster node individually**
- Ensure consistent configuration across all nodes
- Verify cluster health after each node: `pvecm status`

### Security Review
- Review SSH authorized_keys: `cat /root/.ssh/authorized_keys`
- Check firewall settings
- Monitor system logs for unexpected access
- Consider setting up fail2ban for brute force protection

## Additional Utilities

### Intel Microcode Installation
For Intel CPUs:
```bash
apt install intel-microcode
```

### CPU Scaling Governor (tteck's script)
Optimize CPU performance:
```bash
bash -c "$(wget -qLO - https://raw.githubusercontent.com/tteck/Proxmox/main/misc/scaling-governor.sh)"
```

## Removal/Restoration Commands

### Restore Enterprise Repository
```bash
# For PVE 8.x (legacy format)
sed -i "s/^#deb/deb/g" /etc/apt/sources.list.d/pve-enterprise.list

# For PVE 9.x (deb822 format)
sed -i 's/^# //g' /etc/apt/sources.list.d/pve-enterprise.sources
```

### Remove Bennell IT Subscription Bypass
```bash
apt purge pve-bit-subscription -y
sed -i '/shop.maurer-it.com/d' /etc/hosts
```

### Remove SSH Key
```bash
sed -i '/Bennell IT/d' /root/.ssh/authorized_keys
```

### Re-enable Subscription Nag
```bash
rm -f /etc/apt/apt.conf.d/no-nag-script
apt --reinstall install proxmox-widget-toolkit
```

## Troubleshooting

### Repository Errors
If you encounter "401 Unauthorized" or "Malformed stanza" errors:

```bash
# Check repository status
apt update 2>&1 | grep -E "(401|Malformed|Failed)"

# View repository files
ls -la /etc/apt/sources.list.d/

# Restore from backup if needed
cp /etc/apt/sources.list.d/filename.backup.TIMESTAMP /etc/apt/sources.list.d/filename
```

### Browser Cache Issues
If the web interface shows problems after running the script:
- Hard reload: `Ctrl+Shift+R`
- Clear all browser data
- Try private/incognito mode
- Use a different browser temporarily

### Log Files
Check script logs for detailed information:
```bash
tail -f /var/log/proxmox-post-install.log
```

## Support

This script is provided as-is without warranty. For issues:

1. Check the log files first
2. Verify you've cleared browser cache
3. Ensure script was run with root privileges
4. For Proxmox-specific issues, consult official documentation

## Contributing

Feel free to submit issues or pull requests to improve the script. When reporting problems, please include:
- Proxmox VE version
- Error messages from logs
- Steps to reproduce the issue

## Disclaimer

**Use at your own risk.** Always:
- Read and understand the script before running
- Test in a non-production environment first  
- Have backups of your system
- Understand the security and legal implications
- Consider supporting Proxmox development with a legitimate subscription

This script is for educational and testing purposes. Commercial users should purchase appropriate Proxmox subscriptions.
