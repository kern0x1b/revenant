#import "RevenantNW.h"

void nw_advertise_descriptor_set_txt_record_object(nw_advertise_descriptor_t advertise_descriptor, nw_txt_record_t txt_record)
{
    RevenantNWAdvertiseDescriptor *value = (RevenantNWAdvertiseDescriptor *)advertise_descriptor;
    if (!value)
        return;
    value->_txtRecordObject = (RevenantNWTxtRecord *)txt_record;
    value->_txtRecord = nil;
}

nw_txt_record_t nw_advertise_descriptor_copy_txt_record_object(nw_advertise_descriptor_t advertise_descriptor)
{
    RevenantNWAdvertiseDescriptor *value = (RevenantNWAdvertiseDescriptor *)advertise_descriptor;
    if (!value)
        return NULL;
    if (value->_txtRecordObject)
        return nw_txt_record_copy(value->_txtRecordObject);
    if (!value->_txtRecord.length)
        return NULL;
    return nw_txt_record_create_with_bytes((const uint8_t *)value->_txtRecord.bytes, value->_txtRecord.length);
}
