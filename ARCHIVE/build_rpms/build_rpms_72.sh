#!/bin/bash

############################################
# SETTINGS

ROOT_DIR="$PWD"

START_FOLDER_WITH_SRPMS="${ROOT_DIR}"/gigaos_rpms/gigaos_7.2_srpm

BUILD_RPMS_DIR="RPM_BUILD"
export FULL_BUILD_RPMS_DIR="${ROOT_DIR}"/"${BUILD_RPMS_DIR}"

#
############################################


# check if root
if [[ $EUID -ne 0 ]]; then
	echo "This script must be run as root"
	exit 1
fi

# install dependencies to build packages
yum -y install rpm-build redhat-rpm-config make gcc gcc-c++ automake autoconf libtool libattr-devel

#remove old data
echo  "Remove ${FULL_BUILD_RPMS_DIR} if exists"
rm -rf "${FULL_BUILD_RPMS_DIR}"

# create working directories
mkdir -p "${FULL_BUILD_RPMS_DIR}"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

# rewrite macros file

echo '%_topdir %(echo $FULL_BUILD_RPMS_DIR)' > ~/.rpmmacros


# NEED TO COPY PACKAGES TO THE SRPMS FOLDER
rsync -avP "${START_FOLDER_WITH_SRPMS}"/ "${FULL_BUILD_RPMS_DIR}"/SRPMS

# install packages dependies for GigaOS 7.2
PACKAGES=( 
)

for PACKAGE in ${PACKAGES[@]}
do
	echo "Installing ${PACKAGE} package"
	yum -y install ${PACKAGE}
done

# get list of packages and rebuild it one by one
SEARCH_DIR="${FULL_BUILD_RPMS_DIR}/SRPMS"

echo "Search dir: ${SEARCH_DIR}"
cd "${SEARCH_DIR}"

for PACKAGE in "${SEARCH_DIR}"/*.rpm;
do
        echo "+++++++++++++++++++++++++++++++++++++++++++++++++"
	PACKAGE_FILE="$(basename "${PACKAGE}")"
	echo "Repack ${PACKAGE_FILE} package"
	echo "PWD : $PWD"
#	rpmbuild --sign --rebuild ${PACKAGE_FILE}
	yum install -y $(rpmbuild --sign --rebuild ${PACKAGE_FILE} | fgrep 'is needed by' | awk '{print $1}')

	rm -f ${PACKAGE_FILE}
	echo "-------------------------------------------------"
done

cd ${ROOT_DIR}

exit 0

Script started on Thu 01 Feb 2018 06:46:14 PM EET
kroot@centos72:/home/buildos/build_rpms\[root@centos72 build_rpms]# OC[K[Kexit
exit

Script done on Thu 01 Feb 2018 06:48:46 PM EET
