#include "../revenant_impl.h"
#import "RevenantNW.h"
#import "RevenantNWSupport.h"

#include <string.h>

nw_advertise_descriptor_t BACKPORT_IMPL(nw_advertise_descriptor_create_bonjour_service)(const char *name, const char *type, const char *domain)
{
    if (!type || !*type)
        return NULL;
    RevenantNWAdvertiseDescriptor *descriptor = [[RevenantNWAdvertiseDescriptor alloc] init];
    descriptor->_bonjourName = name && *name ? @(name) : nil;
    descriptor->_bonjourType = @(type);
    descriptor->_bonjourDomain = domain ? @(domain) : @"local.";
    return descriptor;
}

void BACKPORT_IMPL(nw_advertise_descriptor_set_txt_record)(nw_advertise_descriptor_t advertise_descriptor, const void *txt_record, size_t txt_length)
{
    RevenantNWAdvertiseDescriptor *value = (RevenantNWAdvertiseDescriptor *)advertise_descriptor;
    if (!value)
        return;
    value->_txtRecord = txt_record ? [NSData dataWithBytes:txt_record length:txt_length] : nil;
}

bool BACKPORT_IMPL(nw_advertise_descriptor_get_no_auto_rename)(nw_advertise_descriptor_t advertise_descriptor)
{
    RevenantNWAdvertiseDescriptor *value = (RevenantNWAdvertiseDescriptor *)advertise_descriptor;
    return value ? value->_noAutoRename : false;
}

void BACKPORT_IMPL(nw_advertise_descriptor_set_no_auto_rename)(nw_advertise_descriptor_t advertise_descriptor, bool no_auto_rename)
{
    RevenantNWAdvertiseDescriptor *value = (RevenantNWAdvertiseDescriptor *)advertise_descriptor;
    if (value)
        value->_noAutoRename = no_auto_rename;
}
