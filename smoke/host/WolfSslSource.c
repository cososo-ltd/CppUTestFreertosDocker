#include <stdio.h>
#include "wolfssl/version.h"

int main(void)
{
    puts(LIBWOLFSSL_VERSION_STRING);
    return 0;
}
