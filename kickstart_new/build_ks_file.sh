#!/bin/bash

ANACONDA_USER_NAME="appassure"
ANACONDA_USER_PASS="appassure"
ANACONDA_HOST_NAME="appassure"
ANACONDA_ROOT_PASS="AppAssure"
ANACONDA_BOOT_DRIVE="sda"
ANACONDA_NETWORK_DEVICE="enno16777736"


ROOT_DIR="$PWD"
NOW=$(date +'%r %d/%m/%Y')
KS_FILE_NAME="ks.cfg"
FULL_KS_FILE_DIR="${ROOT_DIR}/kickstart_build/ks"
FULL_KS_FILE_PATH="${FULL_KS_FILE_DIR}/${KS_FILE_NAME}"

echo "#  ${NOW}" >  ${FULL_KS_FILE_PATH}
cat <<EOT >> ${FULL_KS_FILE_PATH}
# System authorization information
auth --enableshadow -passalgo=sha512

# Use CDROM installation media
cdrom

# Use grafical install
graphical

# Run the Setup Agent on first boot
firstboot --disabled
ignoredisk --only-use=${ANACONDA_BOOT_DRIVE}

# Keyboard layouts
keyboard --vckeymap=us --xlayouts='us'

# System language
lang en_US.UTF-8

# Network information
network --bootproto=dhcp --device=${ANACONDA_NETWORK_DEVICE} --ipv6=auto --activate
network --hostname=${ANACONDA_HOST_NAME}

# Root password
rootpw "${ANACONDA_ROOT_PASS}"

# Users settings
user --groups=wheel --name="${ANACONDA_USER_NAME}" --password="${ANACONDA_USER_PASS}"

# System services
services --disabled="chronyd"

# System timezone
timezone America/New_York --isUtc --nontp

# X Window System configuration information
xconfig --startxonboot

# System bootloader configuration
bootloader --append=" crashkernel=auto" --location=mbr --boot-drive=${ANACONDA_BOOT_DRIVE}
autopart --type=lvm

# Partition clearing information
#clearpart --none --initlabel
clearpart --all

# Reboot after install
reboot --eject

# Accept license
eula --agreed

selinux --disabled

%packages
@^kde-desktop-environment
@base
@core
@desktop-debugging
@dial-up
@directory-client
@fonts
@guest-agents
@guest-desktop-agents
@input-methods
@internet-browser
@java-platform
@kde-desktop
@multimedia
@network-file-system-client
@networkmanager-submodules
@print-client
@x11
kexec-tools

%end

%addon com_redhat_kdump --enable --reserve-mb='auto'

%end
EOT


