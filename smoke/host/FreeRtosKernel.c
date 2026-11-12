#include <stdio.h>
#include "FreeRTOS.h"
#include "task.h"
#include "queue.h"
#include "semphr.h"

int main(void)
{
    puts(tskKERNEL_VERSION_NUMBER);
    return 0;
}
