#!/bin/bash

ROOT_DIR=$PWD

START_FOLDER_WITH_SRPMS=${ROOT_DIR}/SRPMS

BUILD_RPMS_DIR="rpmbuild"
FULL_BUILD_RPMS_DIR=${ROOT_DIR}/${BUILD_RPMS_DIR}
ERROR_FILE="errors"
FULL_ERROR_FILE_PATH=${FULL_BUILD_RPMS_DIR}/${ERROR_FILE}

# check if root
if [[ $EUID -ne 0 ]]; then
	echo "This script must be run as root"
	exit 1
fi

# install dependencies to build packages
yum -y install rpm-build redhat-rpm-config make gcc gcc-c++ automake autoconf libtool libattr-devel

#remove old data
echo  "Remove ${FULL_BUILD_RPMS_DIR}"
rm -rf ${FULL_BUILD_RPMS_DIR}

# create working directories
mkdir -p ${FULL_BUILD_RPMS_DIR}/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

# rewrite macros file
#`echo '%_topdir ${FULL_BUILD_RPMS_DIR}' > ~/.rpmmacros`


# NEED TO COPY PACKAGES TO THE SRPMS FOLDER
rsync -av ${START_FOLDER_WITH_SRPMS}/ ${FULL_BUILD_RPMS_DIR}/SRPMS

# install packages dependencies for GigaOS 5.7
PACKAGES=(
    libidn-devel
    libgpg-error-devel
    gnutls-devel
    php-devel
    aspell-devel
    pcre-devel
    libjpeg-devel
    libtiff-devel
    avahi-compat-libdns_sd-devel
    libgcrypt-devel
    xmlto
    newt-devel
    libacl-devel
    byacc
    gdbm-devel
    pcsc-lite-devel
    libusb-devel
    fontconfig-devel
    freetype-devel
    libpng-devel
    libX11-devel
    libXrender-devel
    dejagnu
    dbus-devel
    readline-devel
    libtermcap-devel
    texinfo
    hesiod-devel
    tcl-devel
    gcc-java
    eclipse-ecj
    java-1.4.2-gcj-compat-devel
    libcap-devel
    libxml2-devel
    emacs
    python-devel
    swig
    intltool
    gettext-devel
    perl-XML-Parser
    glib2-devel
    pam-devel
    bison
    flex
    dbus-glib-devel
    Pyrex
    apr-devel
    openldap-devel
    db4-devel
    expat-devel
    libsysfs-devel
    libaio-devel
    postgresql-devel
    sqlite-devel
    mysql-devel
    ncurses-devel
    doxygen
    audit-libs-devel
    e2fsprogs-devel
    bzip2-devel
    nss-devel
    trousers-devel
    sharutils
    elfutils-devel
    gcc-gnat
    libgnat
    gmp-devel
    gtk2-devel
    xulrunner-devel
    libart_lgpl-devel
    alsa-lib-devel
    libXtst-devel
    libXt-devel
    gtk-doc
    libvolume_id-devel
    pciutils-devel
    gperf
    apr-util-devel
    distcache-devel
    xorg-x11-util-macros
    linuxdoc-tools
    unifdef
    lynx
    xorg-x11-xtrans-devel
    ruby-devel
    ruby
    gcc-gfortran
    docbook-utils-pdf
    openldap-clients
    openldap-servers
    libXres-devel
    cman-devel
    texinfo-tex
    parted-devel
    libdhcp4client-devel
    libdhcp6client-devel
    libdhcp-devel
    gpm-devel
    beecrypt-devel
    lm_sensors-devel
    rpm-devel
    nfs-utils-lib-devel
    libevent-devel
    libgssapi-devel
    libwnck-devel
    automake15
    unixODBC-devel
    bind-libbind-devel
    libtool-ltdl-devel
    autoconf213
    libuser-devel
    curl-devel
    httpd-devel
    libc-client-devel
    net-snmp-devel
    gd-devel
    libsemanage-devel
    libpcap-devel
    tk-devel
    tix-devel
    valgrind-devel
    python-setuptools
    wireless-tools-devel
    cups-devel
    nasm
    java-1.6.0-openjdk-devel
    kdelibs-devel
    qt-devel
    libmng-devel
    ncompress
)

for PACKAGE in ${PACKAGES[@]}
do
	yum -y install ${PACKAGE}
done

# get list of packages and rebuild it one by one
SEARCH_DIR=${FULL_BUILD_RPMS_DIR}/SRPMS/

echo "cd ${SEARCH_DIR}"
cd ${SEARCH_DIR}

for CURRENT in "${SEARCH_DIR}/*"
do
        echo "+++++++++++++++++++++++++++++++++++++++++++++++++"
	echo "Repack ${CURRENT}"
	rpmbuild --rebuild ${CURRENT}
	rm -f ${SEARCH_DIR}/${CURRENT}
#	rpm -resign ${current} 2 > ${FULL_ERROR_FILE_PATH}
	echo "-------------------------------------------------"
done

exit 0

