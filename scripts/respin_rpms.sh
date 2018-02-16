#!/bin/nash

# install dependencies

set -e

echo "PATH: $PATH"
echo "RESPIN_RPMS script build dir $GIGAOS_RESPIN_BUILD_DIR"
exit 0


source ../config.cfg
source ./common.sh

echo "start script to respin the packages"

chechIfUserIsRoot || (echo "Please run as root"; exit 1)

# install dependencies
yum -y install rpm-build redhat-rpm-config make gcc gcc-c++ automake autoconf libtool libattr-devel

# remove old data
echo "Remove ${GIGAOS_RESPIN_BUILD_DIR}" if exists
rm -rf ${GIGAOS_RESPIN_BUILD_DIR}

#create working dirs
mkdir -p "${GIGAOS_RESPIN_BUILD_DIR}"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

# rewrite macros file
echo '%topdir %(echo ${GIGAOS_RESPIN_BUILD_DIR})' > ~/.rpmmacros

# copy SRPMS to build dir
rsync -avP "${GIGAOS_RESPIN_FROLDER_WITH_SRPMS}"/ "${GIGAOS_RESPIN_BUILD_DIR}"/SRPMS

SEARCH_DIR="${GIGAOS_RESPIN_BUILD_DIR}/SRPMS"

echo "Search dir: ${SEARCH_DIR}"
cd "${SEARCH_DIR}"

for PACKAGE in "${SEARCH_DIR}"/*.rpm;
do
    echo "++++++++++++++++++++++++++++++"
    PACKAGE_FILE="$(basename "${PACKAGE}")"
    echo "Repack ${PACKAGE_FILE} package"
    echo "RWD: ${PWD}"

    # install dependencies
    yum install -y $(rpmbuild --sign --rebuild ${PACKAGE_FILE} | fgrep 'is needed by' | awk '{print $1}')

    rm -f ${PACKAGE_FILE}
    rm -rf ${GIGAOS_RESPIN_BUILD_DIR}/BUILD/*
    rm -rf ${GIGAOS_RESPIN_BUILD_DIR}/SOURCES/*
    rm -rf ${GIGAOS_RESPIN_BUILD_DIR}/SPECS/*
    echo "------------------------------"
done

cd ${GIGAOS_ROOT_DIR}


