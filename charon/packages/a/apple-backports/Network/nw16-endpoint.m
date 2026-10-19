/*
 * The two calls of iOS 16 an endpoint answers: the TXT record a Bonjour endpoint carries, and the
 * signature that names the kind of service it is.
 *
 * A TXT record is what a Bonjour service says about itself, and a signature is the fixed prefix
 * that says which kind of service a name is - `_http._tcp` begins with a signature that says it is
 * an HTTP-over-TCP service, and a program can tell a service's kind without parsing its type. An
 * endpoint of another kind has neither, and answers nothing for both, as the host does, measured.
 */

#import "CharonNW.h"

nw_txt_record_t nw_endpoint_copy_txt_record(nw_endpoint_t endpoint)
{
    CharonNWEndpoint *value = (CharonNWEndpoint *)endpoint;
    if (!value || value->_type != nw_endpoint_type_bonjour_service)
        return NULL;
    return value->_txtRecord;
}

const uint8_t *nw_endpoint_get_signature(nw_endpoint_t endpoint, size_t *out_signature_length)
{
    CharonNWEndpoint *value = (CharonNWEndpoint *)endpoint;
    if (!value || value->_type != nw_endpoint_type_bonjour_service || !value->_signature)
        return NULL;
    if (out_signature_length)
        *out_signature_length = value->_signature.length;
    return (const uint8_t *)value->_signature.bytes;
}
