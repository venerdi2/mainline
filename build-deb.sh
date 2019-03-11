#!/bin/bash
# Generates .deb packages
# Requires (at least):
#   apt install ubuntu-dev-tools	# install pbuilder-dist
#   pbuilder-dist cosmic i386 create	# create a build environment
#   pbuilder-disp cosmic amd64 create	# create a build environment

backup=${PWD}
DIR=${0%*/}
cd $DIR

. ./BUILD_CONFIG

sh build-source.sh

build_deb_for_dist() {

dist=$1
arch=$2

echo ""
echo "=========================================================================="
echo " build-deb.sh : $dist-$arch"
echo "=========================================================================="
echo ""

mkdir -pv release/${arch}

echo "-------------------------------------------------------------------------"

pbuilder-dist $dist $arch build release/source/${pkg_name}*.dsc --buildresult release/$arch 

if [ $? -ne 0 ]; then cd "$backup"; echo "Failed"; exit 1; fi

echo "--------------------------------------------------------------------------"

cp -pv --no-preserve=ownership release/${arch}/${pkg_name}*.deb release/${pkg_name}-v${pkg_version}-${arch}.deb 

if [ $? -ne 0 ]; then cd "$backup"; echo "Failed"; exit 1; fi

echo "--------------------------------------------------------------------------"

}

build_deb_for_dist cosmic i386
build_deb_for_dist cosmic amd64
#build_deb_for_dist stretch armel
#build_deb_for_dist stretch armhf

cd "$backup"
