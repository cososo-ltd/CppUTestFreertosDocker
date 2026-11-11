#!/usr/bin/env bash
# Smoke-tests a built cpputest-freertos-cross image from inside it. It checks
# what this layer adds, not any project built on the image: arm-none-eabi-gcc
# compiles the kernel, its Cortex-M3 port and the CMSIS-RTOS2 wrapper over it,
# QEMU and GDB answer, and Behave is the release the dockerfile pins. The
# layer beneath is the host image, smoked by smoke/host/smoke.sh. See README.md.
#
# Usage, from the repository root:
#   docker run --rm -v "$PWD:/smoke:ro" <image> /smoke/smoke/cross/smoke.sh /smoke/dockerfile.cross
set -euo pipefail

dockerfile="$1"
here="$(cd "$(dirname "$0")" && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

kernel="${FREERTOS_KERNEL_PATH}"
port="${kernel}/portable/GCC/ARM_CM3"
wrapper="${CMSIS_FREERTOS_PATH}/CMSIS/RTOS2/FreeRTOS"

echo "== tools"
for tool in arm-none-eabi-gcc arm-none-eabi-gdb qemu-system-arm; do
    version="$("${tool}" --version 2>&1 | sed -n 1p)" || {
        echo "${tool}: ${version}" >&2
        exit 1
    }
    printf '%-20s %s\n' "${tool}" "${version}"
done

echo "== Cortex-M3"
for source in "${kernel}/tasks.c" "${kernel}/queue.c" "${kernel}/list.c" \
    "${kernel}/timers.c" "${port}/port.c" "${wrapper}/Source/cmsis_os2.c"; do
    arm-none-eabi-gcc -mcpu=cortex-m3 -mthumb -Werror=implicit-function-declaration \
        -DCMSIS_device_header='"SmokeDevice.h"' \
        -I"${here}/config" -I"${kernel}/include" -I"${port}" \
        -I"${CMSIS_PATH}/CMSIS/RTOS2/Include" -I"${CMSIS_PATH}/CMSIS/Core/Include" \
        -I"${wrapper}/Include" \
        -c "${source}" -o "${work}/$(basename "${source}").o"
    printf '%-20s %s\n' "$(basename "${source}")" "compiles"
done

echo "== Behave"
expected="$(sed -n 's/.*behave==\([^ ]*\).*/\1/p' "${dockerfile}")"
actual="$(behave --version | sed 's/^behave //')"
if [ -z "${expected}" ] || [ "${actual}" != "${expected}" ]; then
    echo "behave: the dockerfile pins '${expected}', the image has ${actual}" >&2
    exit 1
fi
echo "behave ${actual}"

echo "== smoke passed"
