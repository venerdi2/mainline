#!/bin/bash
# Generates debian source dsc and tar files
# This is run by build-deb.sh

################################################################################
#functions

abrt () { echo "${SELF}: ${@:-Failed}" >&2 ; exit 1 ; }

################################################################################
# main

SELF=${0##*/}
cd ${0%/*} || abrt "Failed to cd \"${0%/*}\"" 

echo ""
echo "=========================================================================="
echo " ${0}"
echo "=========================================================================="
echo ""

# get pkg name from BRANDING.mak
[[ "${BRANDING[SHORTNAME]}" ]] || {
	unset BRANDING ;declare -A BRANDING
	[[ -s BRANDING.mak ]] && while read k x v ; do
		[[ "${k}" =~ ^BRANDING_ ]] && BRANDING[${k#*_}]="${v}"
	done < BRANDING.mak
}
[[ "${BRANDING[SHORTNAME]}" ]] || abrt "Missing BRANDING_SHORTNAME (check BRANDING.mak)"

echo "pkg name: ${BRANDING[SHORTNAME]}"
echo "--------------------------------------------------------------------------"

# clean build dir
rm -rfv /tmp/builds
mkdir -pv /tmp/builds
make clean
mkdir -pv release/source
echo "--------------------------------------------------------------------------"

# build source package
dpkg-source --build . || abrt
mv -vf ../${BRANDING[SHORTNAME]}*.dsc release/source/ || abrt
mv -vf ../${BRANDING[SHORTNAME]}*.tar.* release/source/ || abrt

echo "--------------------------------------------------------------------------"

# list files
ls -l release/source
echo "-------------------------------------------------------------------------"
