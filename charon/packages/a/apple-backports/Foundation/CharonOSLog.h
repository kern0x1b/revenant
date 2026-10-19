#import <Foundation/Foundation.h>
#import <os/log.h>
#include <stdarg.h>

// os/object.h makes os_log_t an Objective-C object, and declares the protocol
// OS_os_log, only where OS_OBJECT_USE_OBJC is on: from a deployment target of
// iOS 6.0. Below it os_log_t is a plain struct os_log_s pointer, and a
// CharonOSLog crosses it with a __bridge cast. No ownership moves either way:
// every CharonOSLog lives as long as the process.
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
// The buffer path: what an os_log macro packs for _os_log_impl and its siblings, decoded and written. The
// records the caller packed are read with the same conversions as the varargs path, and a disabled log writes
// nothing. charon_os_log_disabled_marker is the subsystem of the object OS_LOG_DISABLED names.
char *charon_os_log_format_buffer(const char *format, const uint8_t *buffer, uint32_t size, int error);
void charon_os_log_buffer(os_log_t log, os_log_type_t type, const char *format, const uint8_t *buffer, uint32_t size, int error);
extern char charon_os_log_disabled_marker[];

// The layout of a log object that is not a CharonOSLog of its own: the isa, then the two names the class keeps. The
// default log and OS_LOG_DISABLED are made of it, so it has to match the class's ivars in order.
struct os_log_s {
    Class isa;
    const char *subsystem;
    const char *category;
};
char *charon_os_log_format(const char *format, va_list arguments, int error);
