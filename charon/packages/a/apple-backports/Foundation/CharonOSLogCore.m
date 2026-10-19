#import "CharonOSLog.h"
#include <asl.h>

@implementation CharonOSLog

- (instancetype)initWithSubsystem:(const char *)subsystem category:(const char *)category
{
    if ((self = [super init])) {
        _subsystem = strdup(subsystem);
        _category = strdup(category);
    }
    return self;
}

@end

os_log_t charon_os_log_named(const char *subsystem, const char *category)
{
    static NSMutableDictionary *logs;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        logs = [NSMutableDictionary dictionary];
    });
    NSString *key = [NSString stringWithFormat:@"%s%c%s", subsystem, 0, category];
    @synchronized (logs) {
        CharonOSLog *log = logs[key];
        if (!log) {
            log = [[CharonOSLog alloc] initWithSubsystem:subsystem category:category];
            logs[key] = log;
        }
        return (CHARON_OS_LOG_BRIDGE os_log_t)log;
    }
}

char charon_os_log_disabled_marker[1];

BOOL charon_os_log_type_enabled(os_log_t log, os_log_type_t type)
{
    if (!log || ((CHARON_OS_LOG_BRIDGE CharonOSLog *)log)->_subsystem == charon_os_log_disabled_marker)
        return NO;
    return type != OS_LOG_TYPE_INFO && type != OS_LOG_TYPE_DEBUG;
}

static void charon_os_log_write(os_log_t log, os_log_type_t type, char *text);

void charon_os_log_send(os_log_t log, os_log_type_t type, const char *format, va_list arguments, int error)
{
    charon_os_log_write(log, type, charon_os_log_format(format, arguments, error));
}

void charon_os_log_buffer(os_log_t log, os_log_type_t type, const char *format, const uint8_t *buffer, uint32_t size, int error)
{
    if (!charon_os_log_type_enabled(log, type))
        return;
    charon_os_log_write(log, type, charon_os_log_format_buffer(format, buffer, size, error));
}

static void charon_os_log_write(os_log_t log, os_log_type_t type, char *text)
{
    CharonOSLog *named = (CHARON_OS_LOG_BRIDGE CharonOSLog *)log;
    const char *category = named->_category && *named->_category ? named->_category : NULL;
    int level = type == OS_LOG_TYPE_FAULT ? ASL_LEVEL_CRIT : type == OS_LOG_TYPE_ERROR ? ASL_LEVEL_ERR : ASL_LEVEL_NOTICE;
    aslmsg message = asl_new(ASL_TYPE_MSG);
    if (named->_subsystem && *named->_subsystem)
        asl_set(message, ASL_KEY_FACILITY, named->_subsystem);
    asl_log(NULL, message, level, "%s%s%s%s", category ? "[" : "", category ?: "", category ? "] " : "", text);
    asl_free(message);
    free(text);
}
