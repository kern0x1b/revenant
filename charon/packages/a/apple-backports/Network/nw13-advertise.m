/*
 * The TXT record of an advertised service, as an object: the calls of iOS 13 that take and return
 * the record a listener publishes rather than its bytes.
 *
 * The two forms are one record: the bytes a program hands are parsed into key-value pairs, and what
 * is asked back is a copy of the record, so a program that sets the record object and a listener that
 * publishes its bytes publish the same thing. Setting one replaces the other, which is what the
 * host's own Network does, measured.
 */

#import "CharonNW.h"

void nw_advertise_descriptor_set_txt_record_object(nw_advertise_descriptor_t advertise_descriptor, nw_txt_record_t txt_record)
{
    CharonNWAdvertiseDescriptor *value = (CharonNWAdvertiseDescriptor *)advertise_descriptor;
    if (!value)
        return;
    value->_txtRecordObject = (CharonNWTxtRecord *)txt_record;
    value->_txtRecord = nil;
}

nw_txt_record_t nw_advertise_descriptor_copy_txt_record_object(nw_advertise_descriptor_t advertise_descriptor)
{
    CharonNWAdvertiseDescriptor *value = (CharonNWAdvertiseDescriptor *)advertise_descriptor;
    if (!value)
        return NULL;
    if (value->_txtRecordObject)
        return nw_txt_record_copy(value->_txtRecordObject);
    /* The record a program set as bytes is the same record, asked for as an object: the pairs are
       made from the bytes, which is what the host's own Network answers
       (tests/backports/host/network-objects). */
    if (!value->_txtRecord.length)
        return NULL;
    return nw_txt_record_create_with_bytes((const uint8_t *)value->_txtRecord.bytes, value->_txtRecord.length);
}
