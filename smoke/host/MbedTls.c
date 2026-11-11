/* Compiled and linked with Mbed TLS's own library/version.c, so the header
 * and the source both answer. */
#include <stdio.h>
#include <string.h>
#include "mbedtls/version.h"

int main(void)
{
    char library[sizeof(MBEDTLS_VERSION_STRING)];
    mbedtls_version_get_string(library);
    int ok = strcmp(library, MBEDTLS_VERSION_STRING) == 0;
    puts(ok ? MBEDTLS_VERSION_STRING : "header and library disagree");
    return ok ? 0 : 1;
}
