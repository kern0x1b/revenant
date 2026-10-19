// disabled.m - what OS_LOG_DISABLED answers for each type, from the host's own object and from the port's.
// The same program is built both ways (-DCHARON_PORT for the port), and its two outputs are compared whole.
#import <Foundation/Foundation.h>
#import <os/log.h>
#include <stdio.h>
#ifdef CHARON_PORT
#include "CharonOSLog.h"
extern struct os_log_s _os_log_disabled;
#define DISABLED ((__bridge os_log_t)&_os_log_disabled)
#define ENABLED(log, type) charon_os_log_type_enabled((log), (type))
#else
#define DISABLED OS_LOG_DISABLED
#define ENABLED(log, type) os_log_type_enabled((log), (type))
#endif

int main(void)
{
    const os_log_type_t types[] = {OS_LOG_TYPE_DEFAULT, OS_LOG_TYPE_INFO, OS_LOG_TYPE_DEBUG, OS_LOG_TYPE_ERROR, OS_LOG_TYPE_FAULT};
    for (unsigned index = 0; index < sizeof types / sizeof types[0]; index++)
        printf("type %d enabled %d\n", (int)types[index], ENABLED(DISABLED, types[index]) ? 1 : 0);
    return 0;
}
