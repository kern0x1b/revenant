#import <Foundation/Foundation.h>
#import <os/log.h>
#include <stdarg.h>

#if OS_OBJECT_USE_OBJC
#define CHARON_OS_LOG_BRIDGE
@interface CharonOSLog : NSObject <OS_os_log> {
#else
#define CHARON_OS_LOG_BRIDGE __bridge
@interface CharonOSLog : NSObject {
#endif
@public
    const char *_subsystem;
    const char *_category;
}
@end

os_log_t charon_os_log_named(const char *subsystem, const char *category);
BOOL charon_os_log_type_enabled(os_log_t log, os_log_type_t type);
void charon_os_log_send(os_log_t log, os_log_type_t type, const char *format, va_list arguments, int error);
char *charon_os_log_format_buffer(const char *format, const uint8_t *buffer, uint32_t size, int error);
void charon_os_log_buffer(os_log_t log, os_log_type_t type, const char *format, const uint8_t *buffer, uint32_t size, int error);
extern char charon_os_log_disabled_marker[];

struct os_log_s {
    Class isa;
    const char *subsystem;
    const char *category;
};
char *charon_os_log_format(const char *format, va_list arguments, int error);
