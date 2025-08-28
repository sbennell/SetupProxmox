#!/usr/bin/perl
use strict;
use PVE::INotify;
use PVE::Cluster;
use Sys::Hostname;
use POSIX qw(ceil);

my $nodename = PVE::INotify::nodename();
my $localip = PVE::Cluster::remote_node_ip($nodename, 1);
my $year = `date +%Y`;
chomp($year);
my $hostname = hostname;
my $xline = '*' x 78;

# Hardware Information Collection
sub get_hardware_info {
    my %hw_info;
    
    # CPU Information
    my $cpu_info = `lscpu | grep "Model name" | head -1`;
    chomp($cpu_info);
    $cpu_info =~ s/Model name:\s*//;
    my $cpu_cores = `nproc`;
    chomp($cpu_cores);
    my $cpu_threads = `nproc --all`;
    chomp($cpu_threads);
    
    # Memory Information
    my $mem_total = `grep MemTotal /proc/meminfo | awk '{print \$2}'`;
    chomp($mem_total);
    $mem_total = ceil($mem_total / 1024 / 1024); # KB → GB rounded up
    
    # Storage Information - disk count only
    my $disk_count = `lsblk -ndo TYPE | grep -c '^disk'`;
    chomp($disk_count);
    
    # Network Interface Information
    my $primary_iface = `ip route | grep default | awk '{print \$5}' | head -1`;
    chomp($primary_iface);
    my $mac_addr = `cat /sys/class/net/$primary_iface/address 2>/dev/null`;
    chomp($mac_addr);
    
    # BIOS/UEFI and System info
    my $system_vendor = `dmidecode -s system-manufacturer 2>/dev/null | head -1`;
    chomp($system_vendor);
    my $system_model = `dmidecode -s system-product-name 2>/dev/null | head -1`;
    chomp($system_model);
    
    # Clean up generic/unhelpful hardware strings
    if ($system_vendor =~ /^(Default string|To be filled|System manufacturer|Unknown)$/i) {
        $system_vendor = "";
    }
    if ($system_model =~ /^(Default string|To be filled|System Product Name|Unknown)$/i) {
        $system_model = "";
    }
    
    # Operating System info
    my $os_info = `cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2`;
    chomp($os_info);
    
    # Get Proxmox version if available
    my $pve_version = "";
    if (-e "/usr/bin/pveversion") {
        my $pve_info = `pveversion --verbose | head -1`;
        chomp($pve_info);

        # Match old or new Proxmox VE formats
        if ($pve_info =~ m{pve-manager/([0-9][^/\s]+)}) {
            $pve_version = "Proxmox VE $1";
        } elsif ($pve_info =~ m{proxmox-ve:\s*([0-9][^\s\)]+)}) {
            $pve_version = "Proxmox VE $1";
        }
    }
    
    # Construct final OS string
    my $final_os = $pve_version ? "$pve_version ($os_info)" : $os_info;
    
    my $kernel_info = `uname -r`;
    chomp($kernel_info);
    
    return {
        cpu_model     => $cpu_info || "Unknown CPU",
        cpu_cores     => $cpu_cores || "Unknown",
        cpu_threads   => $cpu_threads || "Unknown", 
        memory        => $mem_total || "Unknown",
        disk_count    => $disk_count || "0",
        primary_iface => $primary_iface || "Unknown",
        mac_addr      => $mac_addr || "Unknown",
        system_vendor => $system_vendor,
        system_model  => $system_model,
        os_info       => $final_os || "Unknown",
        kernel_info   => $kernel_info || "Unknown"
    };
}

my $hw = get_hardware_info();

my $banner = '';
if ($localip) {
    $banner .= <<'__EOBANNER';
****************************************************************************** 
888888b.                                       888 888     8888888 88888888888
888  "88b                                      888 888       888       888
888  .88P                                      888 888       888       888
8888888K.   .d88b.  88888b.  88888b.   .d88b.  888 888       888       888
888  "Y88b d8P  Y8b 888 "88b 888 "88b d8P  Y8b 888 888       888       888
888    888 88888888 888  888 888  888 88888888 888 888       888       888
888   d88P Y8b.     888  888 888  888 Y8b.     888 888       888       888
8888888P"   "Y8888  888  888 888  888  "Y8888  888 888     8888888     888
                              www.bennellit.com.au                        
****************************************************************************** 
__EOBANNER

    $banner .= "                         Welcome to $hostname\n";
    $banner .= "                  Web Management: https://$localip:8006/\n";
    $banner .= "$xline\n";
    $banner .= "  SYSTEM INFORMATION:\n";
    $banner .= "  OS:       $hw->{os_info}\n";
    $banner .= "  Kernel:   $hw->{kernel_info}\n";

    if ($hw->{system_vendor} || $hw->{system_model}) {
        my $hw_string = "";
        $hw_string .= $hw->{system_vendor} if $hw->{system_vendor};
        $hw_string .= " " if ($hw->{system_vendor} && $hw->{system_model});
        $hw_string .= $hw->{system_model} if $hw->{system_model};
        $banner .= "  Hardware: $hw_string\n";
    }

    $banner .= "  CPU:      $hw->{cpu_model}\n";
    $banner .= "  Cores:    $hw->{cpu_cores} cores, $hw->{cpu_threads} threads\n";
    $banner .= "  Memory:   $hw->{memory} GB RAM\n";
    $banner .= "  Storage:  $hw->{disk_count} disks detected\n";
    $banner .= "  Network:  $hw->{primary_iface} ($hw->{mac_addr})\n";
    $banner .= "  IP:       $localip\n";
    $banner .= "$xline\n";
}

open(my $issue_fh, ">/etc/issue") or die "Cannot open /etc/issue: $!";
print $issue_fh $banner;
close($issue_fh);

exit 0;
