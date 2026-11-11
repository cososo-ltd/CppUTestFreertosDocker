#!/usr/bin/env bash
# Smoke-tests a built cpputest-freertos image from inside it. It checks the
# trees a bump changes, not any project built on the image: each upstream is
# where its environment variable points, one translation unit compiles against
# it with the image's gcc, and where the upstream's header carries a version,
# that version is the one the dockerfile pins. See README.md.
#
# Usage, from the repository root:
#   docker run --rm -v "$PWD:/smoke:ro" <image> /smoke/smoke/host/smoke.sh /smoke/dockerfile.host
set -euo pipefail

dockerfile="$1"
here="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

kernel=(-I"${here}/config" -I"${FREERTOS_KERNEL_PATH}/include"
    -I"${FREERTOS_KERNEL_PATH}/portable/ThirdParty/GCC/Posix")

pinned_tag() {
    local tag
    tag="$(sed -n "s/^ARG $1_TAG=//p" "${dockerfile}")"
    if [ -z "${tag}" ]; then
        echo "$1: no ARG $1_TAG in ${dockerfile}" >&2
        exit 1
    fi
    echo "${tag}"
}

# compile NAME SOURCE... -- FLAGS...: builds an executable from SOURCE with gcc.
compile() {
    local name="$1"
    shift
    local sources=()
    while [ "$1" != "--" ]; do
        sources+=("$1")
        shift
    done
    shift
    gcc "${sources[@]}" "$@" -o "${work}/${name}"
}

# reports NAME EXPECTED: runs NAME and fails unless it prints EXPECTED.
reports() {
    local actual
    actual="$("${work}/$1")"
    if [ "${actual}" != "$2" ]; then
        echo "$1: the dockerfile pins $2, the tree says ${actual}" >&2
        exit 1
    fi
    printf '%-18s %s\n' "$1" "${actual}"
}

compiles() {
    printf '%-18s %s\n' "$1" "compiles"
}

compile FreeRtosKernel "${here}/FreeRtosKernel.c" -- "${kernel[@]}"
reports FreeRtosKernel "$(pinned_tag FREERTOS_KERNEL)"

# The header lags its tag (V4.4.1 at V4.4.2), so only the compile is checked.
compile FreeRtosPlusTcp "${here}/FreeRtosPlusTcp.c" -- "${kernel[@]}" \
    -I"${FREERTOS_PLUS_TCP_PATH}/source/include" \
    -I"${FREERTOS_PLUS_TCP_PATH}/source/portable/Compiler/GCC"
compiles FreeRtosPlusTcp

compile FreeRtosPlusFat "${here}/FreeRtosPlusFat.c" -- "${kernel[@]}" \
    -I"${FREERTOS_PLUS_FAT_PATH}/include"
compiles FreeRtosPlusFat

compile Lwip "${here}/Lwip.c" -- -I"${here}/config" \
    -I"${LWIP_PATH}/src/include" -I"${LWIP_PATH}/contrib/ports/unix/port/include"
reports Lwip "$(pinned_tag LWIP | sed -e 's/^STABLE-//' -e 's/_RELEASE$//' -e 's/_/./g')"

gcc -c "${FATFS_PATH}/source/ff.c" -o "${work}/ff.o"
gcc -c "${here}/FatFs.c" -I"${FATFS_PATH}/source" -o "${work}/FatFs.o"
compiles FatFs

compile LittleFs "${here}/LittleFs.c" "${LITTLEFS_PATH}/lfs.c" "${LITTLEFS_PATH}/lfs_util.c" -- \
    -I"${LITTLEFS_PATH}"
reports LittleFs "$(pinned_tag LITTLEFS | sed 's/^v//' | cut -d. -f1,2)"

compile MbedTls "${here}/MbedTls.c" "${MBEDTLS_DIR}/library/version.c" -- \
    -I"${MBEDTLS_DIR}/include" -I"${MBEDTLS_DIR}/library"
reports MbedTls "$(pinned_tag MBEDTLS | sed 's/^v//')"

compile WolfSslSource "${here}/WolfSslSource.c" -- -I"${WOLFSSL_SOURCE_DIR}"
reports WolfSslSource "$(pinned_tag WOLFSSL | sed -e 's/^v//' -e 's/-stable$//')"

compile Cmsis "${here}/Cmsis.c" -- -I"${CMSIS_PATH}/CMSIS/RTOS2/Include"
compiles Cmsis

# CMSIS-FreeRTOS compiles only for a Cortex-M core; the cross image's smoke
# builds it. Here, the tree is where the variable says.
test -f "${CMSIS_FREERTOS_PATH}/CMSIS/RTOS2/FreeRTOS/Source/cmsis_os2.c"
printf '%-18s %s\n' CmsisFreeRtos "present; compiled by the cross smoke"

echo "== smoke passed"
