#!/bin/bash

thisscript="$0"
thisscriptdir="$(dirname $thisscript)"

echo "this script:[$thisscript]"

if [ -d "$thisscriptdir/../yocto" ]; then
  pushd "$thisscriptdir/.."
else
 # Azure pipeline launches a copy of this script from iot-mist root directory location.
 # The copy itself is located in some random location other than the normal $thisscriptdir location.
  echo "Pipeline working directory is: [$PWD]"
fi


print_help()
{
	echo "buildyocto.sh [-i imageType] [-B dir] [-v version] [-r dmagent_commit_hash] [-h] [-M sstate_folder]"
	echo " -h              print this help"
  echo " -v version      version number to assign to device image built."
	echo " -B build_dir    main build directory. Default is machine name."
  echo " -r dmagent_commit_hash	commit hash of dmagent repo."
  echo " -n buildnumber  build number injected by pipeline."
  echo " -t threadcount  Max number of threads BitBake uses to run tasks."
  echo " -j parallelmake Max number of threads Make can run." 
	echo " -M sstateMrrFolder sstate mirror folder.  This folder must have subfolder 'sstate_mirror1' and 'sstate_mirror2'."       
  echo " -S              build eSDK instead of image"
}

setlocalconfig()
{
	if ! grep "$1 $2 $3" $BUILDDIR/conf/local.conf > /dev/null ; then
		echo "$1 $2 $3" >> $BUILDDIR/conf/local.conf
		echo "adding $1 $2 $3 to conf/local.conf"
	fi
}

IMAGETYPE="all"
 
BVERSION="undefined"
IS_SDK=false
while getopts "hi:v:B:r:n:t:j:M:S" opt; do
	case "$opt" in
	h) print_help
	   exit 0;;
	i) IMAGETYPE=$OPTARG;;
  v) BVERSION=$OPTARG;;
	B) BUILD_DIR=$OPTARG;;
  r) DMAGENT_COMMIT_HASH=$OPTARG;;
  n) BUILDNUMBER=$OPTARG;;
  t) THREADCOUNT=$OPTARG;;
  j) PARALLELMAKE=$OPTARG;;
	M) SSTATE_MIRROR_FOLDER=$OPTARG;;
  S) IS_SDK=true;;
	\?) print_help
	    exit 1;;
	esac
done

echo "Building for imageType $IMAGETYPE"
if [ -z ${BUILD_DIR+x} ]; then
    BUILD_DIR="./build_${IMAGETYPE}"
fi

echo "Sourcing build directory to $BUILD_DIR "

TEMPLATECONF="$PWD/configtemplate/all"

if [ -d "$BUILD_DIR/conf" ]; then
  echo "cleaning existing $BUILD_DIR/conf directory .."
  rm -rf "$BUILD_DIR/conf"
fi

OE_INIT_BUILD_ENV=./yocto/poky/oe-init-build-env
SCRIPTS_SRCDIR=$PWD/yocto/poky/scripts

source $OE_INIT_BUILD_ENV $BUILD_DIR
if [ $? -ne 0 ]; then
  echo "oe-init-build-env failed"
  exit 1
fi

setlocalconfig "AZUREDEVICE_BUILDVERSION" "=" "'$BVERSION'"


if ! [ -z ${DMAGENT_COMMIT_HASH+x} ]; then
  setlocalconfig "OVERRIDES" "+=" "':unstable-dmclient'"
  export DMCLIENT_REV="$DMAGENT_COMMIT_HASH"
  export BB_ENV_EXTRAWHITE="$BB_ENV_EXTRAWHITE DMCLIENT_REV"
fi
if ! [ -z ${BUILDNUMBER+x} ]; then
  setlocalconfig "EXTRA_OECMAKE_dmclient" "+=" "' -DBUILDNUMBER=$BUILDNUMBER '"
fi

if ! [ -z ${THREADCOUNT+x} ]; then
  setlocalconfig "BB_NUMBER_THREADS" "=" "\"$THREADCOUNT\""
fi

if ! [ -z ${PARALLELMAKE+x} ]; then
  setlocalconfig "PARALLEL_MAKE" "=" "\"-j $PARALLELMAKE\""
fi

if ! [ -z ${SSTATE_MIRROR_FOLDER+x} ]; then
  setlocalconfig "SSTATE_MIRRORS" "=" "\"file://.* file://$SSTATE_MIRROR_FOLDER/sstate_mirror1/PATH \\n file://.* file://$SSTATE_MIRROR_FOLDER/sstate_mirror2/PATH \""
fi

echo "Starting bitbake... "
bitbake -k core-image-minimal

if [ $? -ne 0 ]; then
  echo "bitbake failed"
  exit 1
fi

echo "Yocto build process completed!"

$SCRIPTS_SRCDIR/buildhistory-collect-srcrevs -a > $IMAGETYPE-buildhistory-srcrevs.txt

echo "Yocto build history srcrevs collected!"
