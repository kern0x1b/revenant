#import "CharonNW.h"
#import "CharonNWSupport.h"

#include <string.h>

nw_advertise_descriptor_t nw_advertise_descriptor_create_bonjour_service(const char *name, const char *type, const char *domain)
{
    if (!type || !*type)
        return NULL;
    CharonNWAdvertiseDescriptor *descriptor = [[CharonNWAdvertiseDescriptor alloc] init];
    descriptor->_bonjourName = name && *name ? @(name) : nil;
    descriptor->_bonjourType = @(type);
    descriptor->_bonjourDomain = domain ? @(domain) : @"local.";
    return descriptor;
}

void nw_advertise_descriptor_set_txt_record(nw_advertise_descriptor_t advertise_descriptor, const void *txt_record, size_t txt_length)
{
    CharonNWAdvertiseDescriptor *value = (CharonNWAdvertiseDescriptor *)advertise_descriptor;
    if (!value)
        return;
    value->_txtRecord = txt_record ? [NSData dataWithBytes:txt_record length:txt_length] : nil;
}

bool nw_advertise_descriptor_get_no_auto_rename(nw_advertise_descriptor_t advertise_descriptor)
{
    CharonNWAdvertiseDescriptor *value = (CharonNWAdvertiseDescriptor *)advertise_descriptor;
    return value ? value->_noAutoRename : false;
}

void nw_advertise_descriptor_set_no_auto_rename(nw_advertise_descriptor_t advertise_descriptor, bool no_auto_rename)
{
    CharonNWAdvertiseDescriptor *value = (CharonNWAdvertiseDescriptor *)advertise_descriptor;
    if (value)
        value->_noAutoRename = no_auto_rename;
}
