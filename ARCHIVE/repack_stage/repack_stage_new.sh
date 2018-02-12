#!/bin/bash

OLD_IMAGE_FILE_NAME="stage2.img"
NEW_IMAGE_FILE_NAME="stage2.img.new"
UNPACK_IMAGE_DIR="centos-stage2"
NEW_IMAGE_DIR="gigaos-stage2-new"

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

/usr/sbin/unsquashfs -dest ${UNPACK_IMAGE_DIR} ${OLD_IMAGE_FILE_NAME}
cd ${UNPACK_IMAGE_DIR}
tar cf - * .buildstamp | (cd ../${NEW_IMAGE_DIR}; tar xfp -)
cd ${NEW_IMAGE_DIR}
/sbin/mksquashfs . ../${NEW_IMAGE_FILE_NAME} -all-root -no-fragments -noappend

exit 0

