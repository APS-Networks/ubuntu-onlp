#! /usr/bin/env bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"


sudo apt-get install python python-pip g++ libi2c-dev libeditline-dev libedit-dev zlib1g-dev ipmitool
pip install pyaml


export ONL=${SCRIPT_DIR}/OpenNetworkLinuxv2
export ONIE_VENDOR=stordis
export ONL_ARCH=x86-64
export ONL_MACHINE=bf6064x-t

export PLATFORM=${ONL_ARCH}-${ONIE_VENDOR}-${ONL_MACHINE}

export SUBMODULE_INFRA="${ONL}/sm/infra"
export SUBMODULE_BIGCODE="${ONL}/sm/bigcode"
export BUILDER="${SUBMODULE_INFRA}/builder/unix"

export BUILDER_MODULE_DATABASE="${ONL}/modules/modules.json"
export BUILDER_MODULE_DATABASE_ROOT="${ONL}"
export BUILDER_MODULE_MANIFEST="${ONL}/modules/modules.mk"

export CC=gcc
#export CFLAGS="-Wno-error -Wno-error=restrict -Wno-error=format-overflow -Wno-error=cpp -lm -Wl,z,now"
#export CFLAGS="-Wno-error=restrict -Wno-error=format-overflow" # -Wno-error -Wno-error=cpp"
export CFLAGS="-g -O0 -pg"


export NO_USE_GCC_VERSION_TOOL=1
export TOOLCHAIN=x86_64-linux-gnu
export ONL_DEBIAN_SUITE=buster


if [ ! -d ${ONL} ]; then
    git clone --depth 1 https://github.com/APS-Networks/OpenNetworkLinuxv2 $ONL --branch staging
    cd ${ONL}

    ${ONL}/tools/submodules.py ${ONL} sm/infra
    ${ONL}/tools/submodules.py ${ONL} sm/bigcode
    ${ONL}/tools/submodules.py ${ONL} sm/build-artifacts


    cd ${ONL}
    git reset --hard
    git clean -xfd

    cd packages/platforms

    # rm -rf accton \
    #     alphanetworks \
    #     celestica \
    #     dell \
    #     dellemc \
    #     delta \
    #     ingrasys \
    #     inventec \
    #     kvm \
    #     lenovo \
    #     mellanox \
    #     mitac \
    #     netberg \
    #     nxp \
    #     qemu \
    #     quanta \
    #     wnc

    cd ${ONL}

    mkdir -p $(dirname ${BUILDER_MODULE_DATABASE})

    
    patch -p1 < ${SCRIPT_DIR}/patches/editline.patch
    patch -p1 < ${SCRIPT_DIR}/patches/onlp-i2c.patch

    PLATFORM_PATCHES=$(find ${SCRIPT_DIR}/patches/${PLATFORM} -type f -name "*.patch" -o -name "*.diff")
    for patch in ${PLATFORM_PATCHES}; do
	echo "Applying patch ${patch}"
        patch -p1 < $patch
    done

fi



cd $ONL

export MODULEMANIFEST=$(${BUILDER}/tools/modtool.py \
    --db ${BUILDER_MODULE_DATABASE} \
    --dbroot ${BUILDER_MODULE_DATABASE_ROOT} \
    --make-manifest ${BUILDER_MODULE_MANIFEST})


read -r -d '' MAKE_ARGS << EOF
    VERBOSE=0 \
    AR=ar \
    ARCH=amd64 \
    BUILDER=${BUILDER} \
    BUILDER_MODULE_DATABASE=${BUILDER_MODULE_DATABASE} \
    BUILDER_MODULE_DATABASE_ROOT=${BUILDER_MODULE_DATABASE_ROOT} \
    BUILDER_MODULE_MANIFEST=${BUILDER_MODULE_MANIFEST} \
    MODULEMANIFEST=${MODULEMANIFEST} \
    GCC=${CC} \
    ONL=${ONL} \
    ONL_DEBIAN_SUITE=${ONL_DEBIAN_SUITE} \
    SUBMODULE_BIGCODE=${SUBMODULE_BIGCODE} \
    SUBMODULE_INFRA=${SUBMODULE_INFRA} \
    TOOLCHAIN=${TOOLCHAIN} \
    PLATFORMS_LIST=${PLATFORM}-r0 \
    PLATFORMS=${PLATFORM}-r0 \
    ONLPM_OPTION_PLATFORM_WHITELIST=${PLATFORM}-r0
EOF


#cp ../onlplib-i2c.patch .

make -C packages/base/any/onlp/builds -j ${ONL_MAKE_PARALLEL} ${MAKE_ARGS} GCC_FLAGS="${CFLAGS}" alltargets
make -C packages/base/any/onlp/builds/onlpd -j ${ONL_MAKE_PARALLEL} ${MAKE_ARGS} GCC_FLAGS="${CFLAGS}" alltargets
make -C packages/platforms/${ONIE_VENDOR}/${ONL_ARCH}/${ONL_MACHINE}/onlp/builds \
    -j ${ONL_MAKE_PARALLEL} ${MAKE_ARGS} GCC_FLAGS="${CFLAGS}" alltargets


cd ${SCRIPT_DIR}

BIN_OUTPUT_DIR=/usr/bin
LIB_OUTPUT_DIR=/lib/x86_64-linux-gnu/


BIN_ONLPD=${ONL}/packages/base/any/onlp/builds/onlpd/BUILD/${ONL_DEBIAN_SUITE}/${TOOLCHAIN}/bin/onlpd
BIN_ONLPS=${ONL}/packages/platforms/${ONIE_VENDOR}/${ONL_ARCH}/${ONL_MACHINE}/onlp/builds/onlps/BUILD/${ONL_DEBIAN_SUITE}/${TOOLCHAIN}/bin/onlps
LIB_DEFAULTS=${ONL}/packages/base/any/onlp/builds/onlp-platform-defaults/BUILD/${ONL_DEBIAN_SUITE}/${TOOLCHAIN}/bin/libonlp-platform-defaults.so
LIB_VENDOR=${ONL}/packages/platforms/${ONIE_VENDOR}/${ONL_ARCH}/${ONL_MACHINE}/onlp/builds/lib/BUILD/${ONL_DEBIAN_SUITE}/${TOOLCHAIN}/bin/libonlp-${ONL_ARCH}-${ONIE_VENDOR}-${ONL_MACHINE}.so
LIB_ONLP=${ONL}/packages/base/any/onlp/builds/onlp/BUILD/${ONL_DEBIAN_SUITE}/${TOOLCHAIN}/bin/libonlp.so

LIB_PLATFORM=${OUTPUT_DIR}/lib/libonlp-platform.so

#mkdir -p output/bin
#mkdir -p output/lib
sudo cp ${BIN_ONLPD}    ${OUTPUT_DIR}/bin/.
sudo cp ${BIN_ONLPS}    ${OUTPUT_DIR}/bin/.
sudo cp ${LIB_DEFAULTS} ${LIB_OUTPUT_DIR}/.
sudo cp ${LIB_VENDOR}   ${LIB_OUTPUT_DIR}/.
sudo cp ${LIB_ONLP}     ${LIB_OUTPUT_DIR}/.

cd ${LIB_OUTPUT_DIR}
sudo ln -f -s libonlp-${ONL_ARCH}-${ONIE_VENDOR}-${ONL_MACHINE}.so libonlp-platform.so
sudo ln -f -s libonlp.so libonlp.so.1
sudo ln -f -s libonlp-platform.so libonlp-platform.so.1
sudo ln -f -s libonlp-platform-defaults.so libonlp-platform-defaults.so.1


sudo mkdir -p /etc/onl
echo ${ONL_ARCH}-${ONIE_VENDOR}-${ONL_MACHINE}-r0 | sudo tee /etc/onl/platform

sudo ldconfig
