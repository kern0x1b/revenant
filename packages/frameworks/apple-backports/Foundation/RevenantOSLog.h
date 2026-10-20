#import <Foundation/Foundation.h>
#import <os/log.h>
#include <stdarg.h>

#if OS_OBJECT_USE_OBJC
#define REVENANT_OS_LOG_BRIDGE
@interface RevenantOSLog : NSObject <OS_os_log> {
#else
#define REVENANT_OS_LOG_BRIDGE __bridge
@interface RevenantOSLog : NSObject {
#endif
@public
    const char *_subsystem;
    const char *_category;
}
@end

os_log_t revenant_os_log_named(const char *subsystem, const char *category);
BOOL revenant_os_log_type_enabled(os_log_t log, os_log_type_t type);
void revenant_os_log_send(os_log_t log, os_log_type_t type, const char *format, va_list arguments, int error);
char *revenant_os_log_format_buffer(const char *format, const uint8_t *buffer, uint32_t size, int error);
void revenant_os_log_buffer(os_log_t log, os_log_type_t type, const char *format, const uint8_t *buffer, uint32_t size, int error);
extern char revenant_os_log_disabled_marker[];

struct os_log_s {
    Class isa;
    const char *subsystem;
    const char *category;
};
char *revenant_os_log_format(const char *format, va_list arguments, int error);
