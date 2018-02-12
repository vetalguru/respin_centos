#!/bin/bash

#
#
# ROOT_FOLDER-+
#             |
#             +-NEW_DATA-+			- direcory with new images
#             |          |
#	      |          +-anaconda-+		- directory with new images for anaconda package
#	      |			    |
#	      |			    +-pixmaps	- incluse many new pictures with logo
#	      |			    |
#	      |			    +-splash	- splash screen with logo
#             +-stage2.img			- image to repack
#	      |
#             +-repack_stage.sh			- sript to repack the image
#             |
#             +-stage2.img.new			- RESULT
#
#



ROOT_DIR=$PWD
STAGE_FILE_PATH="stage2.img"
MOUNT_POINT="image_mount_point"
ARCHIVE_NAME="image.tar"
NEW_STAGE_DIR_NAME="BUILD_IMAGE"
NEW_STAGE_FINAL_FILE_NAME="stage2.img.new"
NEW_DATA_DIR="NEW_DATA"

DIST_NAME="GigaOS"
DIST_BUGCHECK_DOMAIN="bugs.gigaos.com"


# check if root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi


echo "Unpacking the image..." 

mkdir -p ${MOUNT_POINT}
mount -t squashfs -o loop ${STAGE_FILE_PATH} ${MOUNT_POINT}

cd ${MOUNT_POINT}
tar cvf ../${ARCHIVE_NAME} .
cd ../

mkdir -p ${NEW_STAGE_DIR_NAME}
cd ${NEW_STAGE_DIR_NAME}
tar xvf ../${ARCHIVE_NAME}



echo "Change new image..."

# copy anaconda splash screen
cp -rf ${ROOT_DIR}/${NEW_DATA_DIR}/anaconda/splash/syslinux-splash.png ${ROOT_DIR}/${NEW_STAGE_DIR_NAME}/usr/lib/anaconda-runtime/boot/syslinux-splash.png

# copy anaconda pixpams
NEW_STAGE_DIR=${ROOT_DIR}/${NEW_STAGE_DIR_NAME}
rm -rf ${NEW_STAGE_DIR}/usr/share/anaconda/pixmaps/*
cp -rf ${ROOT_DIR}/${NEW_DATA_DIR}/anaconda/pixmaps/* ${NEW_STAGE_DIR}/usr/share/anaconda/pixmaps/

# change buildstamp
BUILDSTAMP_FILE_PATH=${NEW_STAGE_DIR}/.buildstamp
sed -i 's/CentOS/${DIST_NAME}/g' ${BUILDSTAMP_FILE_PATH}
sed -i 's/bugs.centos.org/${DIST_BUGCHECK_DOMAIN}/g' ${BUILDSTAMP_FILE_PATH}

# change CentOS to the GigaOS in rhel.py file
sed -i 's/CentOS/${DIST_NAME}/g' ${NEW_STAGE_DIR}/usr/lib/anaconda/installclasses/rhel.py



echo "Make new image..."

cd ..
/sbin/mksquashfs ${NEW_STAGE_DIR}  ${ROOT_DIR}/${NEW_STAGE_FINAL_FILE_NAME} -all-root -no-fragments -noappend 
chmod -x ${ROOT_DIR}/${NEW_STAGE_FINAL_FILE_NAME}


echo "Remove temp files..."

cd ${ROOT_DIR}
umount ${MOUNT_POINT}
rm -rf ${MOUNT_POINT}
rm -rf ${NEW_STAGE_DIR}
rm -f ${ARCHIVE_NAME}

exit 0

