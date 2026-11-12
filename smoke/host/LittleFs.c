/* Compiled and linked with LittleFS's own lfs.c and lfs_util.c. The header
 * carries major and minor only. */
#include <stdio.h>
#include "lfs.h"

int main(void)
{
    printf("%u.%u\n", (unsigned)LFS_VERSION_MAJOR, (unsigned)LFS_VERSION_MINOR);
    return 0;
}
