#!/bin/bash

#
# Script builds GigaOS from CentOS
#


#################################################
#
# SETTINGS
#
#################################################


#set -e

source ./config.cfg


# NEED PROCESS COMMAND LINE PARAMETERS
# COMMAND LINE PARAMETERS
NEED_RESPIN_RPMS=false
NEED_REPACK_STAGE=false
NEED_BUILD_OS=true
NEED_TO_USE_RESPIN_RPMS=false
NEED_TO_INSTALL_APPASSURE_AGENT=true
NEED_CREATE_OVF=false

CMD_LINE_TC_USER_NAME=""
CMD_LINE_TC_USER_PASSWD=""

# TeamCity auth data
# To use default login and password you need set 
# valiables

# check if user is root
if [ "$EUID" -ne 0 ]; then
    echo "Rlease run as root"
    exit 1
fi

if [ ${NEED_RESPIN_RPMS} = true ]; then


    if [ ! -f ${GIGAOS_RESPIN_SCRIPT} ]; then
        echo "Unable to find script ${GIGAOS_RESPIN_SCRIPT}"
        exit 1
    fi

    if [ ! -d ${GIGAOS_RESPIN_FROLDER_WITH_SRPMS} ]; then
        mkdir -p ${GIGAOS_RESPIN_FROLDER_WITH_SRPMS}
        echo "You need to put srpm packages to the ${GIGAOS_RESPIN_FROLDER_WITH_SRPMS} folder"
        exit 0
    fi

    # install dependencies
    yum -y install rpm-build redhat-rpm-config make gcc \
        gcc-c++ automake autoconf libtool libattr-devel yum-utils

    BUILD_RPMS_DIR="RPM_BUILD"
    export FULL_BUILD_RPMS_DIR="${GIGAOS_RESPIN_BUILD_DIR}/${BUILD_RPMS_DIR}"

    # remove old data
    echo "Remove ${GIGAOS_RESPIN_BUILD_DIR}" if exists
    rm -rf ${GIGAOS_RESPIN_BUILD_DIR}

    #create working dirs
    mkdir -p "${FULL_BUILD_RPMS_DIR}"/{BUILD,RPMS,SOURCE,SPECS,SRPMS,BUILDROOT}

    # rewrite macros file
    echo '%_topdir %(echo $FULL_BUILD_RPMS_DIR)' > ~/.rpmmacros
    echo '%_builddir %{_topdir}/BUILD' >> ~/.rpmmacros
    echo '%_rpmdir %{_topdir}/RPMS' >> ~/.rpmmacros
    echo '%_sourcedir %{_topdir}/SOURCE' >> ~/.rpmmacros
    echo '%_specdir %{_topdir}/SPECS' >> ~/.rpmmacros
    echo '%_srcrpmdir %{_topdir}/SRPMS' >> ~/.rpmmacros
    echo '%_buildrootdir %{_topdir}/BUILDROOT' >> ~/.rpmmacros
    echo '%_tpmpath %{_topdir}/tmp' >> ~/.rpmmacros

    # copy SRPMS to build dir
    rsync -avP "${GIGAOS_RESPIN_FROLDER_WITH_SRPMS}"/ "${FULL_BUILD_RPMS_DIR}"/SRPMS

    # get list of packages and rebuild it one by one
    CH_DIR="${FULL_BUILD_RPMS_DIR}/SRPMS"

    echo "Search dir: ${SEARCH_DIR}"
    cd "${SEARCH_DIR}"

    chmod -p "${GIGAOS_RESPIN_RESULT_DIR}"

    PACKAGE_COUNT=0
    for PACKAGE in "${SEARCH_DIR}"/*.rpm;
    do
        echo "++++++++++++++++++++++++++++++"
        PACKAGE_FILE="$(basename "${PACKAGE}")"
        echo "Repack ${PACKAGE_FILE} package"
        echo "RWD: ${PWD}"

        # install dependencies
        #yum install -y $(rpmbuild --sign --rebuild ${PACKAGE_FILE} | fgrep 'is needed by' | awk '{print $1}')
        yum-builddep -y -v ${PACKAGE_FILE}
        rpmbuild --rebuild ${PACKAGE_FILE}

        rsync -avP ${FULL_BUILD_RPMS_DIR}/RPMS/${GIGAOS_BUILD_ISO_DIST_MACHINE}/* ${GIGAOS_RESPIN_RESULT_DIR}/
        rsync -avP ${FULL_BUILD_RPMS_DIR}/RPMS/noarch/* ${GIGAOS_RESPIN_RESULT_DIR}/

        rm -f ${PACKAGE_FILE}
        rm -rf ${FULL_BUILD_RPMS_DIR}/BUILD/*
        rm -rf ${FULL_BUILD_RPMS_DIR}/SOURCE/*
        rm -rf ${FULL_BUILD_RPMS_DIR}/SPECS/*
        rm -rf ${FULL_BUILD_RPMS_DIR}/BUILDROOT/*
        echo "------------------------------"
        ((PACKAGE_COUNT++))
    done

    echo "Was builded ${PACKAGE_COUNT} package(s)..."

    cd ${GIGAOS_ROOT_DIR}
fi


#if [ ${NEED_REPACK_STAGE} = true ]; then
    # NEED_TO_PROCESS
#fi


if [ ${NEED_BUILD_OS} = true ]; then
    # install dependencies
    yum -y install anaconda anaconda-runtime createrepo mkisofs yum-utils rpm-build

    # umount distributive disk if it was mounted
    if [ -f ${GIGAOS_BUILD_ISO_MOUNT_POINT} ]; then

        if mount | grep -q "${GIGAOS_BUILD_ISO_MOUNT_POINT_NAME}"; then
            umount ${GIGAOS_BUILD_ISO_MOUNT_POINT}
        fi
    fi

    # umount vmware tools iso if it was mounted
    if [ -f ${GIGAOS_BUILD_ISO_VMWARE_MOUNT_POINT} ]; then
        if mount | grep -q "${GIGAOS_BUILD_ISO_VMWARE_MOUNT_POINT_NAME}"; then
            umount ${GIGAOS_BUILD_ISO_VMWARE_MOUNT_POINT}
        fi
    fi

    # remove old data
    rm -rf ${GIGAOS_BUILD_ISO_BUILD_DIR}

    # create build dir
    mkdir -p ${GIGAOS_BUILD_ISO_BUILD_DIR}

    # create folders for iso file
    mkdir -p ${GIGAOS_BUILD_ISO_ROOT_ISO}
    mkdir -p ${GIGAOS_BUILD_ISO_ROOT_ISOLINUX}
    mkdir -p ${GIGAOS_BUILD_ISO_ROOT_ISO}/images
    mkdir -p ${GIGAOS_BUILD_ISO_ROOT_ISO}/ks
    mkdir -p ${GIGAOS_BUILD_ISO_ROOT_ISO}/LiveOS
    mkdir -p ${GIGAOS_BUILD_ISO_ROOT_ISO}/Packages





    # copy AppAssure packages if need
    if [ ${NEED_TO_INSTALL_APPASSURE_AGENT} = true ]; then
        echo "Need to install AppAssure Agent"

        # check if login entered
        if [ -z ${CMD_LINE_TC_USER_NAME} ]; then
            echo "Login is empty. Using default login and passwd"
            CMD_LINE_TC_USER_NAME="${APPASSURE_DEFAULT_TEAM_CITY_USER_NAME}"
            CMD_LINE_TC_USER_PASSWD="${APPASSURE_DEFAULT_TEAM_CITY_USER_PASSWD}"
        fi

        wget --no-check-certificate \
             --http-user="${CMD_LINE_TC_USER_NAME}" \
             --http-passwd="${CMD_LINE_TC_USER_PASSWD}" \
             "${APPASSURE_PACKAGES_HTTP_ADDR_BUILD_VERSION_PAGE}" \
             --output-document="${APPASSURE_PACKAGES_HTTP_ADDR_BUILD_VERSION_FILE}"

        # check if result file exists
        if [ ! -f "${APPASSURE_PACKAGES_HTTP_ADDR_BUILD_VERSION_FILE}" ]; then
            echo "Unable to get TeamCity build version for Agent packages"
            exit 1
        fi

        # parce result file
        FULL_TC_BUILD_NAME=`xmllint --xpath "string(//build/@number)" ${APPASSURE_PACKAGES_HTTP_ADDR_BUILD_VERSION_FILE}`
        echo "${FULL_TC_BUILD_NAME}" > ${APPASSURE_PACKAGES_HTTP_ADDR_BUILD_VERSION_FILE}

        # need to parse build version file
        TC_BUILD_NAME=$(echo ${FULL_TC_BUILD_NAME} | grep -oE '[0-9].[0-9].[0-9].[0-9][0-9][0-9][0-9]')

        echo "Build number: ${TC_BUILD_NAME}"

        # need to pack Agent's rpms
        mkdir -p ${APPASSURE_ISO_AGENT_DIR}

        # download agent rpm
        FULL_AGENT_RPM_NAME="${APPASSURE_RPMS_AGENT_PACKAGE_NAME}-${TC_BUILD_NAME}-${APPASSURE_RPMS_SUFFIX}"
        FULL_PATH_TO_AGENT_RPM="${APPASSURE_RPMS_ARTIFACTS_DOWNLOAD_PATH}${FULL_AGENT_RPM_NAME}"

        wget --no-check-certificate \
            --http-user="${CMD_LINE_TC_USER_NAME}" \
            --http-passwd="${CMD_LINE_TC_USER_PASSWD}" \
            "${FULL_PATH_TO_AGENT_RPM}" \
            --output-document="${APPASSURE_ISO_AGENT_DIR}/${FULL_AGENT_RPM_NAME}"


        # download mono
        FULL_MONO_RPM_NAME="${APPASSURE_RPMS_MONO_PACKAGE_NAME}-${TC_BUILD_NAME}-${APPASSURE_RPMS_SUFFIX}"
        FULL_PATH_TO_MONO_RPM="${APPASSURE_RPMS_ARTIFACTS_DOWNLOAD_PATH}${FULL_MONO_RPM_NAME}"

        echo "HERE > ${FULL_PATH_TO_MONO_RPM}"

        wget --no-check-certificate \
            --http-user="${CMD_LINE_TC_USER_NAME}" \
            --http-passwd="${CMD_LINE_TC_USER_PASSWD}" \
            "${FULL_PATH_TO_MONO_RPM}" \
            --output-document="${APPASSURE_ISO_AGENT_DIR}/${FULL_MONO_RPM_NAME}"

        # download repo
        FULL_REPO_RPM_NAME="${APPASSURE_RPMS_REPO_PACKAGE_NAME}-${TC_BUILD_NAME}-${APPASSURE_RPMS_SUFFIX}"
        FULL_PATH_TO_REPO_RPM="${APPASSURE_RPMS_ARTIFACTS_DOWNLOAD_PATH}${FULL_AGENT_RPM_NAME}"

        wget --no-check-certificate \
            --http-user="${CMD_LINE_TC_USER_NAME}" \
            --http-passwd="${CMD_LINE_TC_USER_PASSWD}" \
            "${FULL_PATH_TO_REPO_RPM}" \
            --output-document="${APPASSURE_ISO_AGENT_DIR}/${FULL_REPO_RPM_NAME}"
    fi

    echo "Mount original cd disk to ${GIGAOS_BUILD_ISO_MOUNT_POINT}"
    mkdir -p ${GIGAOS_BUILD_ISO_MOUNT_POINT}
    mount -t iso9660 -o loop,ro ${GIGAOS_BUILD_ISO_CDROM_DEVICE} ${GIGAOS_BUILD_ISO_MOUNT_POINT}/

    # copy isolinux
    rsync -avP ${GIGAOS_BUILD_ISO_MOUNT_POINT}/isolinux/ ${GIGAOS_BUILD_ISO_ROOT_ISOLINUX}/

    # copy disk info
    rsync -avP ${GIGAOS_BUILD_ISO_MOUNT_POINT}/.diskinfo ${GIGAOS_BUILD_ISO_ROOT_ISOLINUX}/

    # copy images folder
    rsync -avP ${GIGAOS_BUILD_ISO_MOUNT_POINT}/images/ ${GIGAOS_BUILD_ISO_ROOT_ISO}/images/

    # copy LiveOS folder
    rsync -avP ${GIGAOS_BUILD_ISO_MOUNT_POINT}/LiveOS/ ${GIGAOS_BUILD_ISO_ROOT_ISO}/LiveOS/

    # copy comps.xml
    find ${GIGAOS_BUILD_ISO_MOUNT_POINT}/repodata -name '*comps.xml.gz' -exec cp {} ${GIGAOS_BUILD_ISO_ROOT_ISO}/comps.xml.gz \;
    gunzip ${GIGAOS_BUILD_ISO_ROOT_ISO}/comps.xml.gz

    # copy vmware tools
    if [ -f ${GIGAOS_BUILD_ISO_VMWARE_TOOLS_ISO_FILE_PATH} ]; then
        echo "Copy vmware tools to iso dir"
        mkdir -p ${GIGAOS_BUILD_ISO_VMWARE_MOUNT_POINT}

        echo "mount ${GIGAOS_BUILD_ISO_VMWARE_TOOLS_ISO_FILE_PATH} to ${GIGAOS_BUILD_ISO_VMWARE_MOUNT_POINT}"
        mount ${GIGAOS_BUILD_ISO_VMWARE_TOOLS_ISO_FILE_PATH} ${GIGAOS_BUILD_ISO_VMWARE_MOUNT_POINT}

        mkdir -p ${GIGAOS_BUILD_ISO_VMWARE_TOOLS_DIR}
        rsync -avP ${GIGAOS_BUILD_ISO_VMWARE_MOUNT_POINT}/VMwareTools-*.tar.gz "${GIGAOS_BUILD_ISO_VMWARE_TOOLS_DIR}/${GIGAOS_BUILD_ISO_VMWARE_ARCH_FILE_NAME}"

        umount ${GIGAOS_BUILD_ISO_VMWARE_MOUNT_POINT}
        rm -rf ${GIGAOS_BUILD_ISO_VMWARE_MOUNT_POINT}
    else
        echo "Unable to find VMWare tools ${GIGAOS_BUILD_ISO_VMWARE_TOOLS_ISO_FILE_PATH}"
        exit 1
    fi

    # create  KS-file
    mkdir -p ${GIGAOS_BUILD_ISO_ROOT_KS}
    echo "#  ${GIGAOS_BUILD_ISO_ISODATE}" >  ${GIGAOS_BUILD_ISO_ROOT_KS_CFG}
    cat <<EOT >> ${GIGAOS_BUILD_ISO_ROOT_KS_CFG}
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
${VMWARE_ROOT_DIR}/${VMWARE_INSTALL_DIR_NAME}/${VMWARE_ARCH_NAME}
umount ${VMWARE_ROOT_DIR}/${VMWARE_MOUNT_POINT}/

# unpack vmware tools
tar -zxf ${VMWARE_ROOT_DIR}/${VMWARE_INSTALL_DIR_NAME}/${VMWARE_ARCH_NAME} \
-C ${VMWARE_ROOT_DIR}/${VMWARE_INSTALL_DIR_NAME}/

# install vmware tools
yum -y install kernel-devel gcc dracut make perl fuse-libs
chmod +x ${VMWARE_ROOT_DIR}/${VMWARE_INSTALL_DIR_NAME}/vmware-tools-distrib/vmware-install.pl
# start script
. ${VMWARE_ROOT_DIR}/${VMWARE_INSTALL_DIR_NAME}/vmware-tools-distrib/vmware-install.pl --default

# clear data after installation
umount ${VMWARE_ROOT_DIR}/${VMWARE_MOUNT_POINT}/ || /bin/true
rm -rf ${VMWARE_ROOT_DIR}/${VMWARE_INSTALL_DIR_NAME}
rm -rf ${VMWARE_ROOT_DIR}/${VMWARE_MOUNT_POINT}

#
# set autologin for user
#

%end

# Poweroff after install
shutdown

EOT


    # remove unused menu items
    chmod +w ${GIGAOS_BUILD_ISO_ROOT_ISOLINUX_CFG}
    sed -i '/label/,$d' ${GIGAOS_BUILD_ISO_ROOT_ISOLINUX_CFG}

    # add ks-file to default item in installer menu
    echo 'label check_' >> ${GIGAOS_BUILD_ISO_ROOT_ISOLINUX_CFG}
    echo '    menu label Test this ^media & install CentOS 7' >> ${GIGAOS_BUILD_ISO_ROOT_ISOLINUX_CFG}
    echo '    menu default' >> ${GIGAOS_BUILD_ISO_ROOT_ISOLINUX_CFG}
    echo '    kernel vmlinuz' >> ${GIGAOS_BUILD_ISO_ROOT_ISOLINUX_CFG}
    echo '    append initrd=initrd.img inst.stage2=hd:LABEL=CentOS\x207\x20x86_64 rd.live.check inst.ks=cdrom:/dev/cdrom:/ks/ks.cfg' >> ${GIGAOS_BUILD_ISO_ROOT_ISOLINUX_CFG}
    echo '' >> ${GIGAOS_BUILD_ISO_ROOT_ISOLINUX_CFG}
    echo 'menu end' >> ${GIGAOS_BUILD_ISO_ROOT_ISOLINUX_CFG}

    # copy rpms
    rsync -avP ${GIGAOS_BUILD_ISO_MOUNT_POINT}/Packages/ ${GIGAOS_BUILD_ISO_ROOT_ISO}/Packages/

    if [ NEED_TO_USE_RESPIN_RPMS = true ]; then
        echo "Need to use respin rpms"

        mkdir -p ${GIGAOS_BUILD_ISO_BUILD_RESPIN_DIR}

        # NEED TO CHECK IF EXISTS
        rsync -avP ${GIGAOS_RESPIN_RESULT_DIR}/ ${GIGAOS_BUILD_ISO_BUILD_RESPIN_DIR}/

        # GigaOS will need to have own versuin of thes pacakges
        declare -a package_array=("centos-release"
                                "centos-release-notes"
                                "redhat-artwork"
                                "redhat-logos"
                                "specspo"
        )

        # remove dublicates in CentOS repo
        for filepath in ${GIGAOS_BUILD_ISO_BUILD_RESPIN_DIR}/*
        do
            filename=${filepath##*/}
            packagename=${filename%%.*}
            echo ${filename}

            need_to_be_deleted=true
            for i in "${package_array[@]}"
            do
                if [[ ${filename} = *$i* ]]; then
                    need_to_be_deleted=false
                    break
                fi
            done

            if [[ "${need_to_be_deleted}" = false ]]; then
                echo "Skip package ${filename}"
                continue
            fi

            # find in repo
            for entry in ${GIGAOS_BUILD_ISO_ROOT_ISO}/Packages/*
            do
                cur_filename=${entry##*/}
                cur_packagename=${cur_filename%%.*}

                if [[ ${packagename} == ${cur_packagename} ]]; then
                    rm -f ${entry}
                    echo "Remove package ${cur_filename} from CentOS repo"
                fi
            done

        done

        # copy respin rpms to iso-disk packages
        rsync -avP ${GIGAOS_BUILD_ISO_BUILD_RESPIN_DIR} ${GIGAOS_BUILD_ISO_ROOT_ISO}/Packages/

    fi


    # create repodata
    cd ${GIGAOS_BUILD_ISO_ROOT_ISO}/
    createrepo -g comps.xml .
    cd ${GIGAOS_ROOT_DIR}

    # umoun gewneral dvd
    umount ${GIGAOS_BUILD_ISO_MOUNT_POINT}
    rm -rf ${GIGAOS_BUILD_ISO_MOUNT_POINT}

    # rebrending menu
    echo "Rebrending ${GIGAOS_BUILD_ISO_ROOT_ISOLINUX_CFG} file"
    sed -i "s/CentOS/${GIGAOS_BUILD_ISO_DIST_NAME}/g" ${GIGAOS_BUILD_ISO_ROOT_ISOLINUX_CFG}


    # remove old TRANS.TBL files
    find ${GIGAOS_BUILD_ISO_ROOT_ISO}/ -type f -name 'TRANS.TBL' -delete


    # make ISO - file
    FULL_ISOLINUX_BIN_FILE_NAME="${GIGAOS_BUILD_ISO_ROOT_ISOLINUX}/isolinux.bin"
    echo "Set file ${FULL_ISOLINUX_BIN_FILE_NAME} as writable"
    chmod 644 "${FULL_ISOLINUX_BIN_FILE_NAME}"

    echo "Create ISO file ${GIGAOS_BUILD_ISO_ISONAME}, packager \
        ${GIGAOS_BUILD_ISO_DIST_PACKAGER}, \
        date ${GIGAOS_BUILD_ISO_ISODATE}"

    mkisofs -r -R -J -T -v \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        -input-charset utf-8 \
        -V "${GIGAOS_BUILD_ISO_ISONAME}" \
        -p "${GIGAOS_BUILD_ISO_DIST_PACKAGER}" \
        -A "$GIGAOS_BUILD_ISO_ISONAME - $GIGAOS_BUILD_ISO_ISODATE" \
        -b isolinux/isolinux.bin \
        -c isolinux/boot.cat \
        -x "lost+found" \
        --joliet-long \
        -o "${GIGAOS_BUILD_ISO_RESULT_ISO_FILE}" "${GIGAOS_BUILD_ISO_ROOT_ISO}/"


    # signing the iso file
    echo "Signing file ${GIGAOS_BUILD_ISO_RESULT_ISO_FILE}"
    implantisomd5 "${GIGAOS_BUILD_ISO_RESULT_ISO_FILE}"

fi


if [ ${NEED_CREATE_OVF} = true ]; then
    # remove old data
    rm -rf ${GIGAOS_BUILD_OVF_BUILD_DIR}

    # create build dir
    mkdir -p ${GIGAOS_BUILD_OVF_BUILD_DIR}

    # copy iso-file
    if [ ! -f "$GIGAOS_BUILD_ISO_RESULT_ISO_FILE" ]; then
        echo "Unable to find ISO-file ${GIGAOS_BUILD_ISO_RESULT_ISO_FILE}"
        exit 1
    fi

    rsync -avP "${GIGAOS_BUILD_ISO_RESULT_ISO_FILE}" "${GIGAOS_BUILD_OVF_ISO_FILE}"

    # create *.VMX file
    /bin/cat <<EOM >${GIGAOS_BUILD_OVF_VMX_FILE}
#!/usr/bin/vmware
.encoding = "UTF-8"
config.version = "8"
virtualHW.version = "14"
pciBridge0.present = "TRUE"
pciBridge4.present = "TRUE"
pciBridge4.virtualDev = "pcieRootPort"
pciBridge4.functions = "8"
pciBridge5.present = "TRUE"
pciBridge5.virtualDev = "pcieRootPort"
pciBridge5.functions = "8"
pciBridge6.present = "TRUE"
pciBridge6.virtualDev = "pcieRootPort"
pciBridge6.functions = "8"
pciBridge7.present = "TRUE"
pciBridge7.virtualDev = "pcieRootPort"
pciBridge7.functions = "8"
vmci0.present = "TRUE"
hpet0.present = "TRUE"
usb.vbluetooth.startConnected = "TRUE"
displayName = "${GIGAOS_BUILD_OVF_DISPLAY_NAME}"
guestOS = "${GIGAOS_BUILD_OVF_GUEST_OS}"
nvram = "${GIGAOS_BUILD_OVF_DISPLAY_NAME}.nvram"
virtualHW.productCompatibility = "hosted"
powerType.powerOff = "soft"
powerType.powerOn = "soft"
powerType.suspend = "soft"
powerType.reset = "soft"
tools.syncTime = "FALSE"
sound.autoDetect = "TRUE"
sound.fileName = "-1"
sound.present = "TRUE"
vcpu.hotadd = "TRUE"
memsize = "1024"
mem.hotadd = "TRUE"
scsi0.virtualDev = "lsilogic"
scsi0.present = "TRUE"
scsi0:0.fileName = "${GIGAOS_BUILD_OVF_DISK_FILE_NAME}"
scsi0:0.present = "TRUE"
ide1:0.deviceType = "cdrom-image"
ide1:0.fileName = "${GIGAOS_BUILD_OVF_ISO_FILE}"
ide1:0.present = "TRUE"
usb.present = "TRUE"
ehci.present = "TRUE"
ethernet0.connectionType = "nat"
ethernet0.addressType = "generated"
ethernet0.virtualDev = "e1000"
serial0.fileType = "thinprint"
serial0.fileName = "thinprint"
ethernet0.present = "TRUE"
serial0.present = "TRUE"
extendedConfigFile = "${GIGAOS_BUILD_OVF_DISPLAY_NAME}.vmxf"
floppy0.present = "FALSE"
uuid.bios = "56 4d e6 46 a4 6e 49 5c-23 9e 02 2d e2 ab 2c 04"
uuid.location = "56 4d e6 46 a4 6e 49 5c-23 9e 02 2d e2 ab 2c 04"
migrate.hostlog = "./${GIGAOS_BUILD_OVF_DISPLAY_NAME}.hlog"
scsi0:0.redo = ""
pciBridge0.pciSlotNumber = "17"
pciBridge4.pciSlotNumber = "21"
pciBridge5.pciSlotNumber = "22"
pciBridge6.pciSlotNumber = "23"
pciBridge7.pciSlotNumber = "24"
scsi0.pciSlotNumber = "16"
usb.pciSlotNumber = "32"
ethernet0.pciSlotNumber = "33"
sound.pciSlotNumber = "34"
ehci.pciSlotNumber = "35"
vmci0.pciSlotNumber = "36"
ethernet0.generatedAddress = "00:0c:29:ab:2c:04"
ethernet0.generatedAddressOffset = "0"
vmci0.id = "-492098556"
monitor.phys_bits_used = "43"
vmotion.checkpointFBSize = "33554432"
vmotion.checkpointSVGAPrimarySize = "33554432"
cleanShutdown = "FALSE"
softPowerOff = "FALSE"
usb:1.speed = "2"
usb:1.present = "TRUE"
usb:1.deviceType = "hub"
usb:1.port = "1"
usb:1.parent = "-1"
tools.remindInstall = "TRUE"
usb:0.present = "TRUE"
usb:0.deviceType = "hid"
usb:0.port = "0"
usb:0.parent = "-1"
EOM

    # create disk for vm
    vmware-vdiskmanager -c -t 0 -s "${GIGAOS_BUILD_OVF_DISK_SIZE}" -a buslogic "${GIGAOS_BUILD_OVF_DISK_FILE_NAME}"

    # start the vm
    vmrun -T ws start "${GIGAOS_BUILD_OVF_VMX_FILE}" nogui

    # check if started
    vm_run=`vmrun list | grep ${GIGAOS_BUILD_OVF_VMX_FILE}`
    if [[ -z $vm_run ]]; then
        echo "Virtual machine ${GIGAOS_BUILD_OVF_VMX_FILE} was not started"
        exit 1
    fi

    echo "Virtual machine ${GIGAOS_BUILD_OVF_VMX_FILE} was started"

    # wait while virtual machine is installating
    tmp_time=${GIGAOS_BUILD_OVF_MAX_TIMEOUT_TO_CHECK_INSTALLATION}
    while true
    do
        vm_run=`vmrun list | grep ${GIGAOS_BUILD_OVF_VMX_FILE}`
        if [[ -z $vm_run ]]; then
            echo "Virtual machine ${GIGAOS_BUILD_OVF_VMX_FILE} was stopped"
            break
        fi

        sleep ${GIGAOS_BUILD_OVF_TIMEOUT_TO_CHECK_INSTALLATION}

        #((tmp_time--))
        tmp_time=$((${tmp_time}-${GIGAOS_BUILD_OVF_TIMEOUT_TO_CHECK_INSTALLATION}))

        if [[ ${tmp_time} -le 0 ]]; then    # <=
            echo "Timeout error..."
            # stop vm
            vmrun -T ws stop "${GIGAOS_BUILD_OVF_VMX_FILE}" hard
            echo "Virtual machine was stopped"
            exit 1
        fi

        echo "Installation time left ${tmp_time} seconds"

    done

    echo "Vitrual machine was installed"

    # NEED TO PROCESS POSTINSTALL STEPS

    # convert vm to ovf
    echo "Create OVF file"
    ovftool --acceptAllEulas  \
            --compress=${GIGAOS_BUILD_OVF_COMPRESS_VALUE} \
            ${GIGAOS_BUILD_OVF_VMX_FILE} \
            ${GIGAOS_BUILD_OVF_OVF_FILE}


    echo "SUCCESS"
fi


exit 0





