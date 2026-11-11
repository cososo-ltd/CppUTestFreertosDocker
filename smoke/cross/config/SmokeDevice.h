/* A CMSIS device header for a bare Cortex-M3. CMSIS-FreeRTOS includes one
 * through CMSIS_device_header and will not compile outside a CMSIS-Pack build
 * without it; the core's own exceptions are all it reads. */
#ifndef SMOKE_DEVICE_H
#define SMOKE_DEVICE_H

typedef enum IRQn
{
    NonMaskableInt_IRQn = -14,
    HardFault_IRQn = -13,
    MemoryManagement_IRQn = -12,
    BusFault_IRQn = -11,
    UsageFault_IRQn = -10,
    SVCall_IRQn = -5,
    DebugMonitor_IRQn = -4,
    PendSV_IRQn = -2,
    SysTick_IRQn = -1
} IRQn_Type;

#define __CM3_REV 0x0201U
#define __MPU_PRESENT 1U
#define __VTOR_PRESENT 1U
#define __NVIC_PRIO_BITS 3U
#define __Vendor_SysTickConfig 0U

#include "core_cm3.h"

#endif
