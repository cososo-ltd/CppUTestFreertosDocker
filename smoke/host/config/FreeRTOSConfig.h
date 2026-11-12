/* The least the kernel headers need to compile on the POSIX port. */
#ifndef FREERTOS_CONFIG_H
#define FREERTOS_CONFIG_H

#define configUSE_PREEMPTION 1
#define configUSE_IDLE_HOOK 0
#define configUSE_TICK_HOOK 0
#define configTICK_RATE_HZ 1000
#define configMAX_PRIORITIES 5
#define configMINIMAL_STACK_SIZE 128
#define configTOTAL_HEAP_SIZE 65536
#define configTICK_TYPE_WIDTH_IN_BITS TICK_TYPE_WIDTH_32_BITS
#define configUSE_MUTEXES 1
#define configUSE_RECURSIVE_MUTEXES 1
#define configUSE_COUNTING_SEMAPHORES 1
#define configSUPPORT_STATIC_ALLOCATION 1
#define configSUPPORT_DYNAMIC_ALLOCATION 1
#define configUSE_TIMERS 1
#define configNUM_THREAD_LOCAL_STORAGE_POINTERS 3
#define configTIMER_TASK_PRIORITY 2
#define configTIMER_QUEUE_LENGTH 10
#define configTIMER_TASK_STACK_DEPTH 256
#define INCLUDE_vTaskDelay 1
#define INCLUDE_vTaskDelete 1
#define INCLUDE_xTaskGetCurrentTaskHandle 1
#define INCLUDE_xTaskGetSchedulerState 1
#define INCLUDE_uxTaskGetStackHighWaterMark 1
#define INCLUDE_vTaskDelayUntil 1
#define INCLUDE_vTaskSuspend 1
#define INCLUDE_eTaskGetState 1
#define INCLUDE_xTimerPendFunctionCall 1

#endif
