/* The least the FreeRTOS-Plus-FAT headers need to compile. */
#ifndef FREERTOS_FAT_CONFIG_H
#define FREERTOS_FAT_CONFIG_H

#define ffconfigBYTE_ORDER pdFREERTOS_LITTLE_ENDIAN
#define ffconfigCWD_THREAD_LOCAL_INDEX 0

/* The POSIX port leaves this to the application. */
#define portINLINE inline

#endif
