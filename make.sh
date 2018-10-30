#!/bin/bash

function try () {
"$@" || exit -1
}

function abort() {
echo "$1"
exit 1
}

. make.conf

[ -z "$ANDROID_NDK_PATH" ] && abort "Must set ANDROID_NDK_PATH"
[ -z "$ANDROID_MIN_SDK"  ] && abort "Must set ANDROID_MIN_SDK"
which go  > /dev/null      || abort "Must install golang toolchain"
which zip > /dev/null      || abort "Must install zip"

BASE_PATH="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
BUILD_PATH="$BASE_PATH/build"
SRC_PATH="$BASE_PATH/src"
INTERMEDIATES_PATH=$BUILD_PATH/intermediates
OUTPUT_PATH=$BUILD_PATH/outputs

ANDROID_ARM_TOOLCHAIN=$INTERMEDIATES_PATH/toolchains/android-toolchain-${ANDROID_MIN_SDK}-arm
ANDROID_ARM64_TOOLCHAIN=$INTERMEDIATES_PATH/toolchains/android-toolchain-${ANDROID_MIN_SDK}-arm64
ANDROID_X86_TOOLCHAIN=$INTERMEDIATES_PATH/toolchains/android-toolchain-${ANDROID_MIN_SDK}-x86

ANDROID_ARM_CC=$ANDROID_ARM_TOOLCHAIN/bin/arm-linux-androideabi-gcc
ANDROID_ARM_CXX=$ANDROID_ARM_TOOLCHAIN/bin/arm-linux-androideabi-g++
ANDROID_ARM_STRIP=$ANDROID_ARM_TOOLCHAIN/bin/arm-linux-androideabi-strip

ANDROID_ARM64_CC=$ANDROID_ARM64_TOOLCHAIN/bin/aarch64-linux-android-gcc
ANDROID_ARM64_CXX=$ANDROID_ARM64_TOOLCHAIN/bin/arm-linux-androideabi-g++
ANDROID_ARM64_STRIP=$ANDROID_ARM64_TOOLCHAIN/bin/aarch64-linux-android-strip

ANDROID_X86_CC=$ANDROID_X86_TOOLCHAIN/bin/i686-linux-android-gcc
ANDROID_X86_CXX=$ANDROID_X86_TOOLCHAIN/bin/arm-linux-androideabi-g++
ANDROID_X86_STRIP=$ANDROID_X86_TOOLCHAIN/bin/i686-linux-android-strip

try mkdir -p $BUILD_PATH/intermediates/go 
try mkdir -p $INTERMEDIATES_PATH/binary/armeabi-v7a $INTERMEDIATES_PATH/binary/x86 $INTERMEDIATES_PATH/binary/arm64-v8a

if [ ! -d "$ANDROID_ARM_TOOLCHAIN" ]; then
    echo "Make standalone toolchain for ARM arch"
    $ANDROID_NDK_PATH/build/tools/make_standalone_toolchain.py --arch arm \
        --api $ANDROID_MIN_SDK --install-dir $ANDROID_ARM_TOOLCHAIN
fi

if [ ! -d "$ANDROID_ARM64_TOOLCHAIN" ]; then
    echo "Make standalone toolchain for ARM64 arch"
    $ANDROID_NDK_PATH/build/tools/make_standalone_toolchain.py --arch arm64 \
        --api $ANDROID_MIN_SDK --install-dir $ANDROID_ARM64_TOOLCHAIN
fi

if [ ! -d "$ANDROID_X86_TOOLCHAIN" ]; then
    echo "Make standalone toolchain for X86 arch"
    $ANDROID_NDK_PATH/build/tools/make_standalone_toolchain.py --arch x86 \
        --api $ANDROID_MIN_SDK --install-dir $ANDROID_X86_TOOLCHAIN
fi

export GOPATH=$BUILD_PATH/intermediates/go
export PATH=$GOROOT/bin:$GOPATH/bin:$PATH

echo "Get dependences for overture"
go get github.com/tools/godep
go get github.com/shawn1m/overture/main

pushd $GOPATH/src/github.com/shawn1m/overture/main
godep restore

echo "Cross compile overture for arm"
try env CGO_ENABLED=1 CC=$ANDROID_ARM_CC GOOS=android GOARCH=arm GOARM=7 go build -ldflags="-s -w"
try $ANDROID_ARM_STRIP main
try mv main $INTERMEDIATES_PATH/binary/armeabi-v7a/overture

echo "Cross compile overture for arm64"
try env CGO_ENABLED=1 CC=$ANDROID_ARM64_CC GOOS=android GOARCH=arm64 go build -ldflags="-s -w"
try $ANDROID_ARM64_STRIP main
try mv main $INTERMEDIATES_PATH/binary/arm64-v8a/overture

echo "Cross compile overture for x86"
try env CGO_ENABLED=1 CC=$ANDROID_X86_CC GOOS=android GOARCH=386 go build -ldflags="-s -w"
try $ANDROID_X86_STRIP main
try mv main $INTERMEDIATES_PATH/binary/x86/overture

popd

pushd "$SRC_PATH/dns_keeper"

echo "Cross compile dns_keeper for arm"
try env CC=$ANDROID_ARM_CC STRIP=$ANDROID_ARM_STRIP OUTPUT=$INTERMEDIATES_PATH/binary/armeabi-v7a/dns_keeper make -s

echo "Cross compile dns_keeper for arm64"
try env CC=$ANDROID_ARM64_CC STRIP=$ANDROID_ARM64_STRIP OUTPUT=$INTERMEDIATES_PATH/binary/arm64-v8a/dns_keeper make -s 

echo "Cross compile dns_keeper for x86"
try env CC=$ANDROID_X86_CC STRIP=$ANDROID_X86_STRIP OUTPUT=$INTERMEDIATES_PATH/binary/x86/dns_keeper make -s

popd

pushd "$SRC_PATH/daemon"

echo "Cross compile daemon for arm"
try env CC=$ANDROID_ARM_CC STRIP=$ANDROID_ARM_STRIP OUTPUT=$INTERMEDIATES_PATH/binary/armeabi-v7a/daemon make -s

echo "Cross compile daemon for arm64"
try env CC=$ANDROID_ARM64_CC STRIP=$ANDROID_ARM64_STRIP OUTPUT=$INTERMEDIATES_PATH/binary/arm64-v8a/daemon make -s 

echo "Cross compile daemon for x86"
try env CC=$ANDROID_X86_CC STRIP=$ANDROID_X86_STRIP OUTPUT=$INTERMEDIATES_PATH/binary/x86/daemon make -s

popd

echo "Copy zip entries"
mkdir -p $INTERMEDIATES_PATH/zip $INTERMEDIATES_PATH/zip/system/etc/overture
cp -r $INTERMEDIATES_PATH/binary           $INTERMEDIATES_PATH/zip/
cp -r $SRC_PATH/raw/default-configures/*   $INTERMEDIATES_PATH/zip/system/etc/overture
cp -r $SRC_PATH/raw/magisk-module-config/* $INTERMEDIATES_PATH/zip/

pushd $INTERMEDIATES_PATH/zip

echo "Make magisk module zip"
rm    -f $BUILD_PATH/outputs/magisk-module.zip
mkdir -p $BUILD_PATH/outputs
try zip -r $BUILD_PATH/outputs/magisk-module.zip *

popd

echo "Successfully build"
