#include <stdio.h>
#include "lwip/init.h"
#include "lwip/tcp.h"
#include "lwip/udp.h"

int main(void)
{
    puts(LWIP_VERSION_STRING);
    return 0;
}
