#!/bin/bash
# Generates .deb packages
# 2019 Brian K. White <bw.aljex@gmail.com>
# Requires (one time):
#   sudo apt install ubuntu-dev-tools	# install pbuilder-dist
#   pbuilder-dist cosmic i386 create	# create a build environment, repeat for all dists & arches
# Requires (periodically):
#   pbuilder-disp cosmic amd64 update	# update a build environment, repeat for all dists & arches

################################################################################
# functions

abrt () { echo -e "${SELF}: ${@:-Failed}" >&2 ; exit 1 ; }

_mkdeb () {
	echo ""
	echo "=========================================================================="
	echo " ${SELF}: dist=\"${dist}\" arch=\"${arch}\""
	echo "=========================================================================="
	echo ""

	[[ "${dist}" ]] || abrt "_mkdeb(): Missing \"dist\""
	[[ "${arch}" ]] || abrt "_mkdeb(): Missing \"arch\""

	# check if base.tgz exists
	unset a
	[[ "${arch}" == "${host_arch}" ]] || a="-${arch}"
	b=~/pbuilder/${dist}${a}-base.tgz
	[[ -f ${b} ]] || abrt "Missing ${b}\nRun \"pbuilder-dist ${dist} ${arch} create\""
	# TODO - check if base.tgz is old, and automatically run "pbuilder-dist ... update"

	mkdir -pv release/${dist}/${arch}

	CMD="pbuilder-dist ${dist} ${arch} build release/source/${BRANDING[SHORTNAME]}*.dsc --buildresult release/${dist}/${arch}"
	${CMD} || abrt "Failed: \"${CMD}\""

	mv release/${dist}/${arch}/${BRANDING[SHORTNAME]}*.deb release/${dist}/${BRANDING[SHORTNAME]}-v${PKG_VERSION}-${arch}.deb || abrt

}

################################################################################
# main

SELF=${0##*/}
cd ${0%/*} || abrt "Failed cd to \"${0%/*}\""

# get pkg name from BRANDING.mak
unset BRANDING ;declare -A BRANDING
[[ -s BRANDING.mak ]] && while read k x v ;do
	[[ "${k}" =~ ^BRANDING_ ]] && BRANDING[${k#*_}]="${v}"
done < BRANDING.mak
[[ ${BRANDING[SHORTNAME]} ]] || abrt "Missing BRANDING_SHORTNAME (check BRANDING.mak)"

# get pkg version from debian/changelog (not branding.mak)
PKG_VERSION=`dpkg-parsechangelog --show-field Version`

# get deb build targets
host_dist=`lsb_release -sc`
host_arch=`dpkg --print-architecture`
unset DEBS
[[ -s MKDEB_TARGETS ]] && . ./MKDEB_TARGETS		# no err if not present
[[ "${#DEBS[@]}" -lt 1 ]] && declare -A DEBS[${host_dist}]=${host_arch}	# default

export host_dist host_arch BRANDING PKG_VERSION

# generate the source dsc and tar files
./build-source.sh || abrt "Failed: build-source.sh"

# generate debs
for dist in ${!DEBS[@]} ;do
	for arch in ${DEBS[${dist}]//,/ } ;do _mkdeb ;done
done

echo
echo "Generated:"
find release -type f -name '*.deb'

