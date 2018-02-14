#!/bin/bash

ANACONDA_USER_NAME="appassure"
ANACONDA_USER_PASS="appassure"
ANACONDA_HOST_NAME="appassure"
ANACONDA_ROOT_PASS="AppAssure"
ANACONDA_BOOT_DRIVE="sda"
ANACONDA_NETWORK_DEVICE="enno16777736"

VMWARE_ROOT_DIR="/root"
VMWARE_ARCH_NAME="vmware_tools.tar.gz"
VMWARE_INSTALL_DIR_NAME="vmware_tools"
VMWARE_MOUNT_POINT="vmware_mount_point"

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
#graphical
cmdline

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
#reboot --eject

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

# Config the kdump kernel crash dumping mechanism
%addon com_redhat_kdump --enable --reserve-mb='auto'
%end

%post --log=/root/ks-post.log

#
# install vmware tools     =============================
#

# copy vmware tools
mkdir -p $VMWARE_ROOT_DIR/${VMWARE_INSTALL_DIR_NAME}
mkdir -p ${VMWARE_ROOT_DIR}/${VMWARE_MOUNT_POINT}
mount /dev/cdrom ${VMWARE_ROOT_DIR}/${VMWARE_MOUNT_POINT}/
rsync -av ${VMWARE_ROOT_DIR}/${VMWARE_MOUNT_POINT}/${VMWARE_INSTALL_DIR_NAME}/${VMWARE_ARCH_NAME} \
${VMWARE_ROOT_DIR}/${VMWARE_INSTALL_DIR_NAME}
umount ${VMWARE_ROOT_DIR}/${VMWARE_MOUNT_POINT}/

# unpack vmware tools
tar -zxf ${VMWARE_ROOT_DIR}/${VMWARE_INSTALL_DIR_NAME}/${VMWARE_ARCH_NAME}

# install vmware tools
yum -y install kernel-devel gcc dracut make perl fuse-libs
chmod +x ${VMWARE_ROOT_DIR}/${VMWARE_INSTALL_DIR_NAME}/vmware_tools-distrib/vmware-install.pl
. ${VMWARE_ROOT_DIR}/${VMWARE_INSTALL_DIR_NAME}/vmware_tools-distrib/vmware-install.pl --default

# clear data after installation
unmount ${VMWARE_ROOT_DIR}/${VMWARE_MOUNT_POINT}/ || /bin/true
rm -rf ${VMWARE_ROOT_DIR}/${VMWARE_INSTALL_DIR_NAME}
rm -rf ${VMWARE_ROOT_DIR}/${VMWARE_MOUNT_POINT}

%end

# Reboot after install
reboot --eject


EOT


