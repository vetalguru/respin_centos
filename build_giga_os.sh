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
NEED_REPACK_STAGE=true
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

    # IT WILL BE OK TO DOWNLOAD PACKAGES FOR RESPIN

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


if [ ${NEED_BUILD_OS} = true ]; then
    # install dependencies
    yum -y install anaconda anaconda-runtime createrepo mkisofs yum-utils rpm-build pykickstart

    # umount distributive disk if it was mounted
    if [ -f "${GIGAOS_BUILD_ISO_MOUNT_POINT}" ]; then

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

    # copy AppAssure packages to iso-image if need
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

        wget --no-check-certificate \
            --http-user="${CMD_LINE_TC_USER_NAME}" \
            --http-passwd="${CMD_LINE_TC_USER_PASSWD}" \
            "${FULL_PATH_TO_MONO_RPM}" \
            --output-document="${APPASSURE_ISO_AGENT_DIR}/${FULL_MONO_RPM_NAME}"

        # download repo
        FULL_REPO_RPM_NAME="${APPASSURE_RPMS_REPO_PACKAGE_NAME}-${TC_BUILD_NAME}-${APPASSURE_RPMS_SUFFIX}"
        FULL_PATH_TO_REPO_RPM="${APPASSURE_RPMS_ARTIFACTS_DOWNLOAD_PATH}${FULL_REPO_RPM_NAME}"

        wget --no-check-certificate \
            --http-user="${CMD_LINE_TC_USER_NAME}" \
            --http-passwd="${CMD_LINE_TC_USER_PASSWD}" \
            "${FULL_PATH_TO_REPO_RPM}" \
            --output-document="${APPASSURE_ISO_AGENT_DIR}/${FULL_REPO_RPM_NAME}"

        # download nbd
        FULL_NBD_RPM_NAME="${APPASSURE_RPMS_NBD_PACKAGE_NAME}-${TC_BUILD_NAME}-${APPASSURE_RPMS_SUFFIX}"
        FULL_PATH_TO_NBD_RPM="${APPASSURE_RPMS_ARTIFACTS_DOWNLOAD_PATH}${FULL_NBD_RPM_NAME}"

        wget --no-check-certificate \
            --http-user="${CMD_LINE_TC_USER_NAME}" \
            --http-passwd="${CMD_LINE_TC_USER_PASSWD}" \
            "${FULL_PATH_TO_NBD_RPM}" \
            --output-document="${APPASSURE_ISO_AGENT_DIR}/${FULL_NBD_RPM_NAME}"

        # download dkms
        FULL_DKMS_RPM_NAME="${APPASSURE_RPMS_DKMS_PACKAGE_NAME}"  # it has constant name
        FULL_PATH_TO_DKMS_RPM="${APPASSURE_RPMS_ARTIFACTS_DOWNLOAD_PATH}${FULL_DKMS_RPM_NAME}"

        wget --no-check-certificate \
            --http-user="${CMD_LINE_TC_USER_NAME}" \
            --http-passwd="${CMD_LINE_TC_USER_PASSWD}" \
            "${FULL_PATH_TO_DKMS_RPM}" \
            --output-document="${APPASSURE_ISO_AGENT_DIR}/${FULL_DKMS_RPM_NAME}"
    fi

    echo "Mount original cd disk to ${GIGAOS_BUILD_ISO_MOUNT_POINT}"
    mkdir -p ${GIGAOS_BUILD_ISO_MOUNT_POINT}
    mount -t iso9660 -o loop,ro ${GIGAOS_BUILD_ISO_CDROM_DEVICE} ${GIGAOS_BUILD_ISO_MOUNT_POINT}/


    if ! grep "${GIGAOS_BUILD_ISO_MOUNT_POINT}" /proc/mounts; then
        echo "ERROR!!!!!!"
        echo "Original disk NOT mounted!!!"
        echo "Mount original disk and run this script again!"
        exit 1
    fi

    # copy isolinux
    rsync -avP ${GIGAOS_BUILD_ISO_MOUNT_POINT}/isolinux/ ${GIGAOS_BUILD_ISO_ROOT_ISOLINUX}/

    # copy disk info
    rsync -avP ${GIGAOS_BUILD_ISO_MOUNT_POINT}/.discinfo ${GIGAOS_BUILD_ISO_ROOT_ISOLINUX}/

    # copy images folder
    rsync -avP ${GIGAOS_BUILD_ISO_MOUNT_POINT}/images/ ${GIGAOS_BUILD_ISO_ROOT_ISO}/images/

    # copy LiveOS folder
    rsync -avP ${GIGAOS_BUILD_ISO_MOUNT_POINT}/LiveOS/ ${GIGAOS_BUILD_ISO_ROOT_ISO}/LiveOS/

    # copy comps.xml
    find ${GIGAOS_BUILD_ISO_MOUNT_POINT}/repodata -name '*comps.xml.gz' -exec cp {} ${GIGAOS_BUILD_ISO_ROOT_ISO}/comps.xml.gz \;
    gunzip ${GIGAOS_BUILD_ISO_ROOT_ISO}/comps.xml.gz


    # repack stage
    if [ ${NEED_REPACK_STAGE} = true ]; then
        # Anaconda customization guide

        # remove old data
        rm -rf ${STAGE_BUILD_DIR}

        # create root working dir
        mkdir -p ${STAGE_BUILD_DIR}

        # create product dir
        mkdir -p ${STAGE_BUILD_PRODUCT_DIR}

        # copy pixmaps (logo, side bar, top bar, etc.)
        mkdir -p ${STAGE_BUILD_ANACONDA_PIXMAPS_PATH}
        rsync -av ${STAGE_BUILD_ORIGIN_ANACONDA_PIXMAPS_PATH}/ ${STAGE_BUILD_ANACONDA_PIXMAPS_PATH}

        # copy banners for the instalaltion progress screen
        mkdir -p ${STAGE_BUILD_ANACONDA_BANNERS_PATH}
        rsync -av ${STAGE_BUILD_ORIGIN_ANACONDA_INSTALL_BANNERS_PATH}/ ${STAGE_BUILD_ANACONDA_BANNERS_PATH}

        # copy GUI stylesheet
        cp ${STAGE_BUILD_ORIGIN_ANACONDA_STYLE_PATH} ${STAGE_BUILD_ANACONDA_STYLE_PATH}/

        # create producxt class
        mkdir -p ${STAGE_BUILD_ANACONDA_INST_CLASS_PATH}
        echo "#  ${GIGAOS_BUILD_ISO_ISODATE}" > "${STAGE_BUILD_ANACONDA_INST_CLASS_PATH}/custom.py"
        cat <<EOT >> "${STAGE_BUILD_ANACONDA_INST_CLASS_PATH}/custom.py"
from pyanaconda.installclass import BaseInstallClass
from pyanaconda.product import productName
from pyanaconda import network
from pyanaconda import nm

class CustomBaseInstallClass(BaseInstallClass):
    name = "${GIGAOS_BUILD_ISO_DIST_NAME}"
    sortPriority = 30000
    if not productName.startswith("${GIGAOS_BUILD_ISO_DIST_NAME}"):
        hidden = True
    defaultFS = "xfs"
    bootloaderTimeoutDefault = 5
    bootloaderExtraArgs = []

    ignoredPackages = ["ntfsprogs"]

    installUpdates - False

    _l10n_domain = "comps"

    efi_dir = "redhat"

    help_placeholder = "RHEL7Placeholder.html"
    help_placeholder_with_links = "RHEL7PlaceholderWithLinks.html"

    def configure(self, anaconda):
        BaseInstallClass.configure(self, anaconda)
        BaseInstallClass.setDefaultPartitioning(self, anaconda.storage)

    def setNetworkOnbootDefault(self, ksdata):
        if ksdata.method.method not in ("url", "nfs"):
            return
        if network.has_some_wired_autoconnect_device():
            return
        dev = network.default_route_device()
        if not dev:
            return
        if nm.nm_device_type_is_wifi(dev):
            return
        network.update_onboot_value(dev, "yes", ksdata)

    def __init__(self):
        BaseInstallClass.__init__(self)
EOT

        # NEED TO CREATE FILES

        # create img file
        find ${STAGE_BUILD_PRODUCT_DIR} | cpio -c -o | gzip -9cv > "${STAGE_BUILD_DIR}/${STAGE_BUILD_PRODUCT_NAME}.img"

        # move product img to iso images/
        echo "${STAGE_BUILD_DIR}/${STAGE_BUILD_PRODUCT_NAME}.img"
        echo "${GIGAOS_BUILD_ISO_ROOT_ISO}/images/${STAGE_BUILD_PRODUCT_NAME}.img"
        cp "${STAGE_BUILD_DIR}/${STAGE_BUILD_PRODUCT_NAME}.img" "${GIGAOS_BUILD_ISO_ROOT_ISO}/images/${STAGE_BUILD_PRODUCT_NAME}.img"

    fi

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
    cat << EOF > ${GIGAOS_BUILD_ISO_ROOT_KS_CFG}
# System authorization information
auth --enableshadow -passalgo=sha512

# Use CDROM installation media
cdrom

# Use grafical install
#graphical
#cmdline
text

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

# Power off after install
shutdown

# Accept license
eula --agreed

selinux --disabled

%packages --ignoremissing --excludedocs
@base
@core
gcc
-nbd
-dkms
%end

# Config the kdump kernel crash dumping mechanism
%addon com_redhat_kdump --enable --reserve-mb='auto'
%end


%post --log=/root/ks-post.log

# mount ISO-disk
mkdir -p "${GIGAOS_ISO_MOUNT_POINT}"
mount /dev/cdrom "${GIGAOS_ISO_MOUNT_POINT}"


#
# install vmware tools     =============================
#

# copy vmware tools
mkdir -p "${VMWARE_INSTALL_DIR}"

if [ -f "${GIGAOS_ISO_MOUNT_POINT}/${VMWARE_INSTALL_DIR_NAME}/${VMWARE_ARCH_NAME}" ]; then
    rsync -av "${GIGAOS_ISO_MOUNT_POINT}/${VMWARE_INSTALL_DIR_NAME}/${VMWARE_ARCH_NAME}" \
"${VMWARE_INSTALL_DIR}/${VMWARE_ARCH_NAME}"

    # unpack vmware tools
    if [ -f "${VMWARE_INSTALL_DIR}/${VMWARE_ARCH_NAME}" ]; then
        tar -zxf "${VMWARE_INSTALL_DIR}/${VMWARE_ARCH_NAME}" \
-C "${VMWARE_INSTALL_DIR}/"

        # install vmware tools
        yum -y install kernel-devel gcc dracut make perl fuse-libs

        yum -y install open-vm-tools

        #if [ ! -f "${VMWARE_INSTALL_DIR}/vmware-tools-distrib/vmware-install.pl" ]; then
        #    echo "Unable to find vmware-install.pl"
        #fi

        ## start script
        #chmod +x "${VMWARE_INSTALL_DIR}/vmware-tools-distrib/vmware-install.pl"
        #. "${VMWARE_INSTALL_DIR}/vmware-tools-distrib/vmware-install.pl" --default

        # clear data after installation
        #m -rf "${VMWARE_INSTALL_DIR}"
    fi
fi



#
# Install AppAssure agent
#

if [ -d "${GIGAOS_ISO_MOUNT_POINT}/${APPASSURE_ISO_AGENT_DIR_NAME}" ]; then

    mkdir -p "${APPASSURE_GIGAOS_RPMS}"
    rsync -av "${GIGAOS_ISO_MOUNT_POINT}/${APPASSURE_ISO_AGENT_DIR_NAME}/" "${APPASSURE_GIGAOS_RPMS}"

    # install rpms

    # install mono
    rpm -e --nodeps "${APPASSURE_GIGAOS_RPMS}/${APPASSURE_RPMS_MONO_PACKAGE_NAME}*.rpm"
    rpm -i --force "${APPASSURE_GIGAOS_RPMS}/${APPASSURE_RPMS_MONO_PACKAGE_NAME}*.rpm"

    # install repo
    rpm -e --nodeps "${APPASSURE_GIGAOS_RPMS}/${APPASSURE_RPMS_REPO_PACKAGE_NAME}*.rpm"
    rpm -i --force "${APPASSURE_GIGAOS_RPMS}/${APPASSURE_RPMS_REPO_PACKAGE_NAME}*.rpm"

    # install DKMS
    rpm -e --nodeps "${APPASSURE_GIGAOS_RPMS}/dkms-*.rpm"
    rpm -i --force "${APPASSURE_GIGAOS_RPMS}/${APPASSURE_RPMS_DKMS_PACKAGE_NAME}"

    # install nbd
    rpm -e --nodeps "${APPASSURE_GIGAOS_RPMS}/${APPASSURE_RPMS_NBD_PACKAGE_NAME}*.rpm"
    rpm -i --force "${APPASSURE_GIGAOS_RPMS}/${APPASSURE_RPMS_NBD_PACKAGE_NAME}*.rpm"

    # install agent
    rpm -e --nodeps "${APPASSURE_GIGAOS_RPMS}/${APPASSURE_RPMS_AGENT_PACKAGE_NAME}*.rpm"
    rpm -i --force "${APPASSURE_GIGAOS_RPMS}/${APPASSURE_RPMS_AGENT_PACKAGE_NAME}*.rpm"

    # config agent
    /usr/bin/rapidrecovery-config -p ${RAPIDRECOVERY_PORT} \
-u ${ANACONDA_USER_NAME} -f firewalld -m all -v off -s

fi


# umount ISO-disk
umount "${GIGAOS_ISO_MOUNT_POINT}"

#
# User autologin
#

sed -i 's/\<agetty\>/& --autologin ${ANACONDA_USER_NAME}/' /etc/systemd/system/getty.target.wants/getty\@tty1.service


#
# Change os-release file
#
sed -i 's/CentOS/${GIGAOS_BUILD_ISO_DIST_NAME}/g' /etc/os-release

#
# Change centos-release file
#
sed -i 's/CentOS/${GIGAOS_BUILD_ISO_DIST_NAME}/g' /etc/centos-release

#
# update grub menu
#
grub2-mkconfig -o /boot/grub2/grub.cfg

#
# update motd file
#
echo "                                                          " > /etc/motd
echo "      ___                ___                              " >> /etc/motd
echo "     /   |  ____  ____  /   |  ____________  __________   " >> /etc/motd
echo "    / /| | / __ \/ __ \/ /| | / ___/ ___/ / / / ___/ _ \  " >> /etc/motd
echo "   / ___ |/ /_/ / /_/ / ___ |(__  |__  ) /_/ / /  /  __/  " >> /etc/motd
echo "  /_/  |_/ .___/ .___/_/  |_/____/____/\__,_/_/   \___/   " >> /etc/motd
echo "        /_/   /_/                                         " >> /etc/motd
echo "                                                          " >> /etc/motd
echo "                                                          " >> /etc/motd


%end

EOF

    # check kickstart file
    KS_CHECK_RESULT=$(ksvalidator ${GIGAOS_BUILD_ISO_ROOT_KS_CFG})
    if [[ ! -z "${KS_CHECK_RESULT}" ]]; then
        echo "ERROR!!!!"
        echo "Kickstart file errors: ${KS_CHECK_RESULT}"
        exit 1
    else
        echo "KS-file OK"
    fi

    # remove unused menu items
    chmod +w ${GIGAOS_BUILD_ISO_ROOT_ISOLINUX_CFG}
    sed -i '/label/,$d' ${GIGAOS_BUILD_ISO_ROOT_ISOLINUX_CFG}


    # add ks-file to default item in installer menu
    if [ ${NEED_REPACK_STAGE} = true ]; then
        echo 'label check_' >> ${GIGAOS_BUILD_ISO_ROOT_ISOLINUX_CFG}
        echo '    menu label Test this ^media & install CentOS 7' >> ${GIGAOS_BUILD_ISO_ROOT_ISOLINUX_CFG}
        echo '    menu default' >> ${GIGAOS_BUILD_ISO_ROOT_ISOLINUX_CFG}
        echo '    kernel vmlinuz' >> ${GIGAOS_BUILD_ISO_ROOT_ISOLINUX_CFG}
        echo '    append initrd=initrd.img inst.stage2=hd:LABEL=CentOS\x207\x20x86_64 rd.live.check inst.ks=cdrom:/dev/cdrom:/ks/ks.cfg inst.updates=cdrom:/dev/cdrom:/images/product.img' >> ${GIGAOS_BUILD_ISO_ROOT_ISOLINUX_CFG}
        echo '' >> ${GIGAOS_BUILD_ISO_ROOT_ISOLINUX_CFG}
        echo 'menu end' >> ${GIGAOS_BUILD_ISO_ROOT_ISOLINUX_CFG}
    else
        echo 'label check_' >> ${GIGAOS_BUILD_ISO_ROOT_ISOLINUX_CFG}
        echo '    menu label Test this ^media & install CentOS 7' >> ${GIGAOS_BUILD_ISO_ROOT_ISOLINUX_CFG}
        echo '    menu default' >> ${GIGAOS_BUILD_ISO_ROOT_ISOLINUX_CFG}
        echo '    kernel vmlinuz' >> ${GIGAOS_BUILD_ISO_ROOT_ISOLINUX_CFG}
        echo '    append initrd=initrd.img inst.stage2=hd:LABEL=CentOS\x207\x20x86_64 rd.live.check inst.ks=cdrom:/dev/cdrom:/ks/ks.cfg' >> ${GIGAOS_BUILD_ISO_ROOT_ISOLINUX_CFG}
        echo '' >> ${GIGAOS_BUILD_ISO_ROOT_ISOLINUX_CFG}
        echo 'menu end' >> ${GIGAOS_BUILD_ISO_ROOT_ISOLINUX_CFG}
    fi

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

    # NEED TO CHECK IF VMWARE_WORKSTATION WAS INSTALLED
    # IF NOT -> INSTALL IT


    # create *.VMX file
    /bin/cat << EOF >${GIGAOS_BUILD_OVF_VMX_FILE}
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
EOF

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

    echo "Vitrual machine was stopped"

    echo "Starting virtula machine for postinstall settings and checks"

    # start the vm
    vmrun -T ws start "${GIGAOS_BUILD_OVF_VMX_FILE}" nogui

    # check VWware tools
    VMWARE_TOOLS_PS_RESULT=$(vmrun -T ws -gu root -gp ${ANACONDA_ROOT_PASS} listProcessesInGuest "${GIGAOS_BUILD_OVF_VMX_FILE}" | grep vmtoolsd)
    if [[ -z "${VMWARE_TOOLS_PS_RESULT}" ]]; then
        echo "ERROR!!!!"
        echo "VMware tools process not found in guest OS"
    else
        echo "VMware tools process:"
        echo "    ${VMWARE_TOOLS_PS_RESULT}"
    fi

    # check agent service
    AGENT_SERVICE_PS_RESULT=$(vmrun -T ws -gu root -gp ${ANACONDA_ROOT_PASS} listProcessesInGuest "${GIGAOS_BUILD_OVF_VMX_FILE}" | grep mono)
    if [[ -z "${AGENT_SERVICE_PS_RESULT}" ]]; then
        echo "ERROR!!!!"
        echo "Agent process not found in guest OS"
    else
        echo "Agent service process:"
        echo "    ${AGENT_SERVICE_PS_RESULT}"
    fi

    # turn off the vm
    vmrun -T ws stop "${GIGAOS_BUILD_OVF_VMX_FILE}" soft

    echo "Vitrual machine was stopped"

    # convert vm to ovf
    echo "Create OVF file"
    ovftool --acceptAllEulas  \
--compress=${GIGAOS_BUILD_OVF_COMPRESS_VALUE} \
${GIGAOS_BUILD_OVF_VMX_FILE} \
${GIGAOS_BUILD_OVF_OVF_FILE}


    echo "SUCCESS"
fi

exit 0

