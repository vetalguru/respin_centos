#!/bin/bash

ISOFILE="gigaos_new.iso"
PACKAGER="me"
ISONAME="GigaOS 7 x86_64"
ISODATE="2018/02/07"


sudo mkisofs -r -R -J -T -v -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    -V "${ISONAME}" \
    -p "${PACKAGER}" \
    -A "$ISONAME-$ISODATE" \
    -b isolinux/isolinux.bin \
    -c isolinux/boot.cat \
    -x "lost+found" \
    --joliet-long \
    -o $ISOFILE dvd/

implantisomd5 ${ISOFILE}


