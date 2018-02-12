#!/bin/bash

#################################################
#  SETTINGS
#################################################

# general
DISTR_NAME="GigaOS"
DISTR_VERSION="5.7"
DISTR_MACHINE="x86_64"
PACKAGER="Quest"

# workflow
ROOT_DIR=$PWD
ORIGIN_DISK_DEVICE="/dev/cdrw"
ORIGIN_DISK_DIR="origin"
RESPIN_RPMS_DIR="respin_rpms"
BUILD_DIR="ISO_BUILD"

# iso-file info
ISOFILE="${DISTR_NAME}-${DISTR_VERSION}-${DISTR_MACHINE}.iso"
ISONAME="${DISTR_NAME} ${DISTR_VERSION} ${DISTR_MACHINE}"
ISODATE="$(date +'%d/%m/%y')"

# temporary valiables
FULL_RESPIN_RPMS_DIR_PATH=${ROOT_DIR}/${RESPIN_RPMS_DIR}
FULL_BUILD_DIR_PATH=${ROOT_DIR}/${BUILD_DIR}
FULL_ORIGIN_DISK_PATH=${ROOT_DIR}/${ORIGIN_DISK_DIR}


#################################################


#check if root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi


# install dependencies
yum -y install anaconda anaconda-help anaconda-runtime createrepo mkisofs yum-utils rpm-build


# check if started data present
if [[ ! -d "${FULL_RESPIN_RPMS_DIR_PATH}" ]]; then
    mkdir -p ${FULL_RESPIN_RPMS_DIR_PATH}
    echo "Build the ${DIST_NAME} was STOPPED!!!!"
    echo "You need to put new data to the ${FULL_RESPIN_RPMS_DIR_PATH} direstory and try again..."
    exit 1
fi

# create build dir
rm -rf ${FULL_BUILD_DIR_PATH}
mkdir -p ${FULL_BUILD_DIR_PATH}

# remove old iso images
rm -rf ${ROOT_DIR}/*.iso

# copy data from origin disc to build dir
mkdir -p ${FULL_ORIGIN_DISK_PATH}

mount -t iso9660 -o loop,ro ${ORIGIN_DISK_DEVICE} ${FULL_ORIGIN_DISK_PATH}
rsync -avP ${FULL_ORIGIN_DISK_PATH}/ ${FULL_BUILD_DIR_PATH}/

# remove unused dir
umount ${FULL_ORIGIN_DISK_PATH}
rm -rf ${FULL_ORIGIN_DISK_PATH}

# copy license files
#find ${FULL_RESPIN_RPMS_DIR_PATH}/ -maxdep 1 -type f | xargs cp -t ${FULL_BUILD_DIR_PATH}
find ${FULL_RESPIN_RPMS_DIR_PATH}/ -maxdepth 1 -type f -exec cp -t ${FULL_BUILD_DIR_PATH}/ {} +

# clear out TRANS.TBL files
find ${FULL_BUILD_DIR_PATH}/ -type f -name 'TRANS.TBL' -delete




# CREATE REPO
DISCINFO=`head -1 ${FULL_BUILD_DIR_PATH}/.discinfo`
COMPDATA=`find ${FULL_BUILD_DIR_PATH}/repodata -name *comps*xml`
createrepo -u "media://${DISCINFO}" -g ${COMPDATA} ${FULL_BUILD_DIR_PATH}/.





# create ISO-file
chmod +w ${FULL_BUILD_DIR_PATH}/isolinux/isolinux.bin

echo "Create ISO file"
mkisofs -r -R -J -T -v -no-emul-boot \
	-boot-load-size 4 \
	-boot-info-table \
	-V "${ISONAME}" \
	-p "${PACKAGER}" \
	-A "${ISONAME} - ${ISODATE}" \
	-b isolinux/isolinux.bin \
	-c isolinux/boot.cat \
	-x "lost+found" \
	--joliet-long \
	-o $ISOFILE ${FULL_BUILD_DIR_PATH}/


echo "Sign ISO file"
/usr/lib/anaconda-runtime/implantisomd5 ${ISOFILE}

exit 0

