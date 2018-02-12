#!/bin/bash


BUILD_DIR_NAME="kickstart_build"
MOUNT_POINT_NAME="mount_point"
CDROM_DEVICE="/dev/cdrom"

DIST_NAME="GigaOS"
DIST_VERSION="7"
DIST_MACHINE="x86_64"
PACKAGER="Quest Corp."



ROOT_DIR="$PWD"
BUILD_DIR=${ROOT_DIR}/${BUILD_DIR_NAME}
MOUNT_POINT=${ROOT_DIR}/${MOUNT_POINT_NAME}
ISOLINUX_DIR=${BUILD_DIR}/isolinux
FULL_ISOLINUX_CFG_FILE_NAME=${ISOLINUX_DIR}/isolinux.cfg



ISOFILE="${DIST_NAME}-${DIST_VERSION}-${DIST_MACHINE}.iso"
ISONAME="${DIST_NAME} ${DIST_VERSION} ${DIST_MACHINE}"
ISODATE="$(date +'%d/%m/%y')"




#check if root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi




# install dependencies
yum -y install anaconda anaconda-runtime createrepo mkisofs yum-utils rpm-build




# remove old data
rm -rf ${BUILD_DIR}

if mount | grep -q "${MOUNT_POINT_NAME}"; then
    umount ${MOUNT_POINT_NAME}
fi
rm -rf ${MOUNT_POINT}
rm -rf ${ROOT_DIR}/*.iso



# create mount point
mkdir -p ${MOUNT_POINT}




# create folderers for iso file
mkdir -p ${BUILD_DIR}
mkdir -p ${ISOLINUX_DIR}
mkdir -p ${BUILD_DIR}/images
mkdir -p ${BUILD_DIR}/ks
mkdir -p ${BUILD_DIR}/LiveOS
mkdir -p ${BUILD_DIR}/Packages




# mount general cd
mount -t iso9660 -o loop,ro ${CDROM_DEVICE} ${MOUNT_POINT}/




# copy isolinux
rsync -av ${MOUNT_POINT}/isolinux/ ${ISOLINUX_DIR}/




# copy disk info
rsync -av ${MOUNT_POINT}/.discinfo ${ISOLINUX_DIR}/




# copy images folder
rsync -av ${MOUNT_POINT}/images/ ${BUILD_DIR}/images/




#copy LiveOS folder
rsync -av ${MOUNT_POINT}/LiveOS/ ${BUILD_DIR}/LiveOS/




# copy comps.xml
find ${MOUNT_POINT}/repodata -name '*comps.xml.gz' -exec cp {} ${BUILD_DIR}/comps.xml.gz \;
gunzip ${BUILD_DIR}/comps.xml.gz




# copy ks file
rsync -av /root/anaconda-ks.cfg ${BUILD_DIR}/ks/ks.cfg




# add ks-file to default item in installer menu
INSTALL_MENU_ITEM_STRING="label check_
  menu label Test this ^media & install CentOS 7
  menu default
  kernel vmlinuz
  append initrd=initrd.img inst.stage2=hd:LABEL=CentOS\x207\x20x86_64 rd.live.check inst.ks=cdrom:/dev/cdrom:/ks/ks.cfg

menu end"

# remove unused menu items
sed -i '/label/,$d' ${FULL_ISOLINUX_CFG_FILE_NAME}

cat <<EOT>> ${FULL_ISOLINUX_CFG_FILE_NAME}
${INSTALL_MENU_ITEM_STRING}
EOT


# NEED to change ks-file HERE

# copy rpms
rsync -av ${MOUNT_POINT}/Packages/ ${BUILD_DIR}/Packages/




# create repodata
cd ${BUILD_DIR}/
createrepo -g comps.xml .
cd ${ROOT_DIR}




# umount general dvd
umount ${MOUNT_POINT}
rm -rf ${MOUNT_POINT}


# rebrending data
FULL_ISOLINUX_CFG_FILE_NAME=${ISOLINUX_DIR}/isolinux.cfg

echo "Set file ${FULL_ISOLINUX_CFG_FILE_NAME} as writable"
chmod +w ${FULL_ISOLINUX_CFG_FILE_NAME}

echo "Rebrending ${FULL_ISOLINUX_CFG_FILE_NAME} file"
sed -i "s/CentOS/${DIST_NAME}/g" ${FULL_ISOLINUX_CFG_FILE_NAME}



# make ISO - file
FULL_ISOLINUX_BIN_FILE_NAME="${ISOLINUX_DIR}/isolinux.bin"
echo "Set file ${FULL_ISOLINUX_BIN_FILE_NAME} as writable"
chmod 644 "${FULL_ISOLINUX_BIN_FILE_NAME}"

echo "Create ISO file ${ISONAME}, packager ${PACKAGER}, date ${ISODATE}"
mkisofs -r -R -J -T -v \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    -input-charset utf-8 \
    -V "${ISONAME}" \
    -p "${PACKAGER}" \
    -A "$ISONAME - $ISODATE" \
    -b isolinux/isolinux.bin \
    -c isolinux/boot.cat \
    -x "lost+found" \
    --joliet-long \
    -o "${ISOFILE}" "${BUILD_DIR}/"




# signing the iso file
FULL_ISO_FILE_NAME=${ROOT_DIR}/${ISOFILE}
echo "Signing file ${FULL_ISO_FILE_NAME}"
implantisomd5 "${FULL_ISO_FILE_NAME}"




exit 0

