#import "CharonOSSignpost.h"

// The emit path, which is the one piece of the family that arrived in iOS 12 with signpost.h's
// public macros over it; the two id sources and the enabled check are iOS 11 and are in
// CharonOSSignpost11.m, so no object carries API from two releases.

void _os_signpost_emit_with_name_impl(void *dso, os_log_t log, os_signpost_type_t type, os_signpost_id_t spid,
                                     const char *name, const char *format, uint8_t *buf, uint32_t size)
{
    if (spid == OS_SIGNPOST_ID_NULL)
        return;
    switch (type) {
        case OS_SIGNPOST_INTERVAL_BEGIN:
            [CharonSignpostStore recordBeginFor:spid log:log name:name];
            break;
        case OS_SIGNPOST_INTERVAL_END:
            [CharonSignpostStore recordEndFor:spid log:log name:name];
            break;
        case OS_SIGNPOST_EVENT:
            [CharonSignpostStore recordEventFor:spid log:log name:name];
            break;
        default:
            break;
    }
}
