#import "RevenantNW.h"

nw_txt_record_t nw_endpoint_copy_txt_record(nw_endpoint_t endpoint)
{
    RevenantNWEndpoint *value = (RevenantNWEndpoint *)endpoint;
    if (!value || value->_type != nw_endpoint_type_bonjour_service)
        return NULL;
    return value->_txtRecord;
}

const uint8_t *nw_endpoint_get_signature(nw_endpoint_t endpoint, size_t *out_signature_length)
{
    RevenantNWEndpoint *value = (RevenantNWEndpoint *)endpoint;
    if (!value || value->_type != nw_endpoint_type_bonjour_service || !value->_signature)
        return NULL;
    if (out_signature_length)
        *out_signature_length = value->_signature.length;
    return (const uint8_t *)value->_signature.bytes;
}
