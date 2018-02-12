#!/bin/bash

ROOT_DIR=$PWD 
RESPIN_RPMS_DIR=${ROOT_DIR}/respin_rpms
CENTOS_RPMS_DIR=${ROOT_DIR}/ISO_BUILD/CentOS 


# GigaOS will need to have own version of this packages
declare -a package_array=("centos-release"
			  "centos-release-notes"
			  "redhat-artwork"
                          "redhat-logos"
			  "specspo"
			 )

# remove duplicates in CentOS repo
for filepath in ${RESPIN_RPMS_DIR}/*
do
    filename=${filepath##*/}
    packagename=${filename%%.*}
    echo ${filename}

    need_to_be_deleted=true
    for i in "${package_array[@]}"
    do
	if [[ ${filename} = *$i* ]]; then
	    need_to_be_deleted=false
	    break;
	fi
    done

    if [[ "${need_to_be_deleted}" = false ]]; then
        echo "Skip package ${filename}"
	continue
    fi

    # find in repo
    for entry in ${CENTOS_RPMS_DIR}/*
    do
	cur_filename=${entry##*/}
	cur_packagename=${cur_filename%%.*}
	
	if [[ ${packagename} == ${cur_packagename} ]]; then
	    rm -f ${entry}
            echo "Remove package ${cur_filename} from CentOS repo"
	fi

    done

done

# copy respin packages
rsync -av respin_rpms/ ISO_BUILD/CentOS

exit 0

