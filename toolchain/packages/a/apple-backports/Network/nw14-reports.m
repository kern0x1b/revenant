#import "CharonNW.h"

uint64_t nw_resolution_report_get_milliseconds(nw_resolution_report_t resolution_report)
{
    CharonNWResolutionReport *value = (CharonNWResolutionReport *)resolution_report;
    return value ? value->_milliseconds : 0;
}

uint32_t nw_resolution_report_get_endpoint_count(nw_resolution_report_t resolution_report)
{
    CharonNWResolutionReport *value = (CharonNWResolutionReport *)resolution_report;
    return value ? value->_endpointCount : 0;
}

nw_report_resolution_protocol_t nw_resolution_report_get_protocol(nw_resolution_report_t resolution_report)
{
    CharonNWResolutionReport *value = (CharonNWResolutionReport *)resolution_report;
    return value ? value->_protocol : nw_report_resolution_protocol_unknown;
}

nw_report_resolution_source_t nw_resolution_report_get_source(nw_resolution_report_t resolution_report)
{
    CharonNWResolutionReport *value = (CharonNWResolutionReport *)resolution_report;
    return value ? value->_source : nw_report_resolution_source_query;
}

nw_endpoint_t nw_resolution_report_copy_successful_endpoint(nw_resolution_report_t resolution_report)
{
    CharonNWResolutionReport *value = (CharonNWResolutionReport *)resolution_report;
    return value ? value->_successful : NULL;
}

nw_endpoint_t nw_resolution_report_copy_preferred_endpoint(nw_resolution_report_t resolution_report)
{
    CharonNWResolutionReport *value = (CharonNWResolutionReport *)resolution_report;
    return value ? value->_preferred : NULL;
}

void nw_establishment_report_enumerate_resolution_reports(nw_establishment_report_t report, nw_report_resolution_report_enumerator_t enumerate_block)
{
    CharonNWEstablishmentReport *value = (CharonNWEstablishmentReport *)report;
    if (!value || !enumerate_block)
        return;
    for (CharonNWResolutionReport *resolution in value->_resolutionReports) {
        if (!enumerate_block(resolution))
            break;
    }
}
