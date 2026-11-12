#!/usr/bin/env bash
# Smoke-tests a built cpputest-freertos-cross image from inside it. It checks
# what this layer adds, not any project built on the image: arm-none-eabi-gcc
# compiles the kernel, its Cortex-M3 port and the CMSIS-RTOS2 wrapper over it,
# ST's STM32F7 trees are the releases the dockerfile pins and compile for a
# hard-float Cortex-M7, which also links, QEMU and GDB answer, and Behave is
# the release the dockerfile pins. The layer beneath is the host image, smoked
# by smoke/host/smoke.sh. See README.md.
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

echo "== Cortex-M7, hard float"
m7=(-mcpu=cortex-m7 -mthumb -mfpu=fpv5-d16 -mfloat-abi=hard)
hal="${STM32F7_HAL_DRIVER_PATH}"
device="${STM32F7_CMSIS_DEVICE_PATH}"

# ST writes each release into its source as three hex bytes.
st_version() {
    local file="$1" prefix="$2" part value version=""
    for part in MAIN SUB1 SUB2; do
        value="$(sed -n "s/^#define ${prefix}_${part} *(\(0x[0-9A-Fa-f]*\)).*/\1/p" "${file}")"
        if [ -z "${value}" ]; then
            echo "${file}: no ${prefix}_${part}" >&2
            exit 1
        fi
        version="${version}${version:+.}$((value))"
    done
    echo "${version}"
}

st_reports() {
    local name="$1" pin="$2" actual="$3" expected
    expected="$(sed -n "s/^ARG ${pin}_TAG=v//p" "${dockerfile}")"
    if [ -z "${expected}" ] || [ "${actual}" != "${expected}" ]; then
        echo "${name}: the dockerfile pins '${expected}', the tree says ${actual}" >&2
        exit 1
    fi
    printf '%-20s %s\n' "${name}" "${actual}"
}

st_reports Stm32F7HalDriver STM32F7_HAL_DRIVER \
    "$(st_version "${hal}/Src/stm32f7xx_hal.c" __STM32F7xx_HAL_VERSION)"
st_reports Stm32F7CmsisDevice STM32F7_CMSIS_DEVICE \
    "$(st_version "${device}/Include/stm32f7xx.h" __STM32F7_CMSIS_VERSION)"

# The HAL ships its configuration as a template for the project to copy.
cp "${hal}/Inc/stm32f7xx_hal_conf_template.h" "${work}/stm32f7xx_hal_conf.h"
for source in "${hal}/Src/stm32f7xx_hal.c" "${hal}/Src/stm32f7xx_hal_rcc.c" \
    "${hal}/Src/stm32f7xx_hal_gpio.c" "${hal}/Src/stm32f7xx_hal_uart.c" \
    "${hal}/Src/stm32f7xx_hal_eth.c" "${hal}/Src/stm32f7xx_hal_spi.c" \
    "${device}/Source/Templates/system_stm32f7xx.c" \
    "${device}/Source/Templates/gcc/startup_stm32f767xx.s"; do
    arm-none-eabi-gcc "${m7[@]}" -Werror=implicit-function-declaration \
        -DSTM32F767xx -DUSE_HAL_DRIVER \
        -I"${work}" -I"${hal}/Inc" -I"${device}/Include" -I"${CMSIS_PATH}/CMSIS/Core/Include" \
        -c "${source}" -o "${work}/$(basename "${source}").o"
    printf '%-20s %s\n' "$(basename "${source}")" "compiles"
done

# A link, because the compile alone does not need the hard-float newlib the
# toolchain packages have to carry for this core.
echo 'int main(void) { return 0; }' > "${work}/main.c"
arm-none-eabi-gcc "${m7[@]}" --specs=nano.specs --specs=nosys.specs \
    "${work}/main.c" -o "${work}/main.elf"
printf '%-20s %s\n' "newlib-nano" "links from $(arm-none-eabi-gcc "${m7[@]}" -print-multi-directory)"

echo "== Behave"
expected="$(sed -n 's/.*behave==\([^ ]*\).*/\1/p' "${dockerfile}")"
actual="$(behave --version | sed 's/^behave //')"
if [ -z "${expected}" ] || [ "${actual}" != "${expected}" ]; then
    echo "behave: the dockerfile pins '${expected}', the image has ${actual}" >&2
    exit 1
fi
echo "behave ${actual}"

echo "== smoke passed"
