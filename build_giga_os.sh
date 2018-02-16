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
source ./scripts/common.sh

export GIGAOS_CONFIG_FILE=${GIGAOS_ROOT_DIR}/config.cfg

NEED_RESPIN_RPMS=true
NEED_REPACK_STAGE=false
NEED_BUILD_OS=false
NEED_CREATE_OVF=false

# check if user is root
checkIfUserIsRoot || (echo "Please run as root"; exit 1)


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
    SEARCH_DIR="${FULL_BUILD_RPMS_DIR}/SRPMS"

    echo "Search dir: ${SEARCH_DIR}"
    cd "${SEARCH_DIR}"

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

    #create build dir
    mkdir -p ${GIGAOS_BUILD_ISO_BUILD_DIR}

    # create folders for iso file
    mkdir -p ${GIGAOS_BUILD_ISO_ROOT_ISO}
    mkdir -p ${GIGAOS_BUILD_ISO_ROOT_ISOLINUX}
    mkdir -p ${GIGAOS_BUILD_ISO_ROOT_ISO}/images
    mkdir -p ${GIGAOS_BUILD_ISO_ROOT_ISO}/ks
    mkdir -p ${GIGAOS_BUILD_ISO_ROOT_ISO}/LiveOS
    mkdir -p ${GIGAOS_BUILD_ISO_ROOT_ISO}/Packages

    # mount generaal cd
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
        mount -t iso9660 ${GIGAOS_BUILD_ISO_VMWARE_TOOLS_ISO_FILE_PATH} ${GIGAOS_BUILD_ISO_VMWARE_MOUNT_POINT}

        mkdir -p ${GIGAOS_BUILD_ISO_VMWARE_TOOLS_DIR}
        rsunc -avP ${GIGAOS_BUILD_ISO_VMWARE_MOUNT_POINT}/VMWareTools-*.tar.gz "${GIGAOS_BUILD_ISO_VMWARE_TOOLS_DIR}/${GIGAOS_BUILD_ISO_VMWARE_ARCH_FILE_NAME}"

        umount ${GIGAOS_BUILD_ISO_VMWARE_MOUNT_POINT}
        rm -rf ${GIGAOS_BUILD_ISO_VMWARE_MOUNT_POINT}
    else
        echo "Unable to find VMWare tools ($GIGAOS_BUILD_ISO_VMWARE_TOOLS_ISO_FILE_PATH)"
        exit 1
    fi

    # create or copy KS-file
    if [ -f "${GIGAOS_BUILD_ISO_KS_SCRIPT}" ]; then
        source ${GIGAOS_BUILD_ISO_KS_SCRIPT}
    else
        echo "Using standart anaconda-ks.cfg file"
        rsync -avP /root/anaconda-ks.cfg ${GIGAOS_BUILD_ISO_ROOT_ISO}/ks/ks.cfg
    fi

    # add ks-file to default item in installer menu
    INSTALL_MENU_ITEM_STRING="label check_
    menu label Test this ^media & install CentOS 7
    menu default
    kernel vmlinuz
    append initrd=initrd.img inst.stage2=hd:LABEL=CentOS\x207\x20x86_64 rd.live.check inst.ks=cdrom:/dev/cdrom:/ks/ks.cfg

    menu end"

    # remove unused menu items
    chmod +w ${GIGAOS_BUILD_ISO_ROOT_ISOLINUX_CFG}
    sed -i '/label/,$d' ${GIGAOS_BUILD_ISO_ROOT_ISOLINUX_CFG}

    cat <<EOT >> ${GIGAOS_BUILD_ISO_ROOT_ISOLINUX_CFG}
    ${INSTALL_MENU_ITEM_STRING}
    EOT

    # copy rpms
    rsync -av ${GIGAOS_BUILD_ISO_MOUNT_POINT}/Packages/ ${GIGAOS_BUILD_ISO_ROOT_ISO}/Packages/

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
        -o "${GIGAOS_BUILD_ISO_ISOFILE}" "${GIGAOS_BUILD_ISO_ROOT_ISO}/"


    # signing the iso file
    echo "Signing file ${GIGAOS_BUILD_ISO_RESULT_ISO_FILE}"
    implantisomd5 "${GIGAOS_BUILD_ISO_RESULT_ISO_FILE}"

fi


if [ ${NEED_CREATE_OVF} = true ]; then
    # remove old data
    rm -rf ${GIGAOS_BUILD_OVF_BUILD_DIR}

    # create build dir
    mkdir -p ${GIGAOS_BUILD_OVF_BUILD_DIR}

    # create *.VMX file
    /bin/cat <<EOM >${FULL_VHD_FILE_PATH}
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

    # NEED TO WAIT FOR OS INSTALLATION (vmrun)
    # NEED TO DO POSTINSTALL STEPS
    # NEED TO STOP VM
    # NEED TO CONVERT VM to OVF
fi


exit 0

