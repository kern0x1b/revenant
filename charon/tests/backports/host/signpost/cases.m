#import <Foundation/Foundation.h>
#import <os/log.h>
#import <os/signpost.h>
#import "signpost-cases.h"
#import <objc/message.h>
#import <unistd.h>

os_log_t charon_port_os_log_create(const char *subsystem, const char *category)
{
    return os_log_create(subsystem, category);
}

void signpost_run(CertificateRecorder record)
{
    os_log_t log = os_log_create("com.apple.metrickit.log", "charon-test");
    record(@"log.isEnabled", os_log_is_enabled(log) ? @"1" : @"0");
    record(@"signpost.enabled", os_signpost_enabled(log) ? @"1" : @"0");
    os_signpost_id_t first = os_signpost_id_generate(log);
    os_signpost_id_t second = os_signpost_id_generate(log);
    record(@"id.first", [NSString stringWithFormat:@"%llx", (unsigned long long)first]);
    record(@"id.second", [NSString stringWithFormat:@"%llx", (unsigned long long)second]);
    record(@"id.distinct", first != second ? @"1" : @"0");
    record(@"id.isNotNull", first == OS_SIGNPOST_ID_NULL ? @"0" : @"1");
    int anchor = 0;
    int same = 0;
    os_signpost_id_t fromPointer = os_signpost_id_make_with_pointer(log, &anchor);
    os_signpost_id_t fromSame = os_signpost_id_make_with_pointer(log, &same);
    record(@"id.pointerIsStable", fromPointer == fromSame ? @"1" : @"0");
    record(@"id.pointerIsNotReserved",
           (fromPointer != OS_SIGNPOST_ID_NULL && fromPointer != OS_SIGNPOST_ID_INVALID) ? @"1" : @"0");
    record(@"id.pointerFromNullIsNotReserved",
           (os_signpost_id_make_with_pointer(log, NULL) != OS_SIGNPOST_ID_NULL) ? @"1" : @"0");
}
