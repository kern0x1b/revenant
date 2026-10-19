/*
 * The reports a connection is asked for once it is up, and every call of connection_report.h that
 * arrived in iOS 13: what a connection measured while it was being established, and what it moved
 * while it was open.
 *
 * Both are filled by the connection out of its own state machine - the times it took, the attempts
 * before it, the addresses it tried, the protocols of the stack, the bytes it moved - and are read
 * back here. A data transfer report is a snapshot: until the block of nw_data_transfer_report_collect
 * has been given it, it is outstanding and every value answers 0, which is what the header says a
 * report that is not collected answers. The connection's counters are in the report all the same,
 * so the numbers appear the moment it is collected and do not change after.
 */

#import "CharonNW.h"
#import "CharonNWSupport.h"

#include <string.h>

#pragma mark - establishment

uint64_t nw_establishment_report_get_duration_milliseconds(nw_establishment_report_t report)
{
    CharonNWEstablishmentReport *value = (CharonNWEstablishmentReport *)report;
    return value ? value->_durationMilliseconds : 0;
}

uint64_t nw_establishment_report_get_attempt_started_after_milliseconds(nw_establishment_report_t report)
{
    CharonNWEstablishmentReport *value = (CharonNWEstablishmentReport *)report;
    return value ? value->_attemptStartedAfterMilliseconds : 0;
}

uint32_t nw_establishment_report_get_previous_attempt_count(nw_establishment_report_t report)
{
    CharonNWEstablishmentReport *value = (CharonNWEstablishmentReport *)report;
    return value ? value->_previousAttemptCount : 0;
}

bool nw_establishment_report_get_proxy_configured(nw_establishment_report_t report)
{
    CharonNWEstablishmentReport *value = (CharonNWEstablishmentReport *)report;
    return value ? value->_proxyConfigured : false;
}

bool nw_establishment_report_get_used_proxy(nw_establishment_report_t report)
{
    CharonNWEstablishmentReport *value = (CharonNWEstablishmentReport *)report;
    return value ? value->_usedProxy : false;
}

nw_endpoint_t nw_establishment_report_copy_proxy_endpoint(nw_establishment_report_t report)
{
    CharonNWEstablishmentReport *value = (CharonNWEstablishmentReport *)report;
    return value ? value->_proxyEndpoint : NULL;
}

void nw_establishment_report_enumerate_protocols(nw_establishment_report_t report, nw_report_protocol_enumerator_t enumerate_block)
{
    CharonNWEstablishmentReport *value = (CharonNWEstablishmentReport *)report;
    if (!value || !enumerate_block)
        return;
    for (NSUInteger index = 0; index < value->_protocols.count; index++) {
        if (!enumerate_block(value->_protocols[index], [value->_protocolHandshakeMilliseconds[index] unsignedLongLongValue],
                              [value->_protocolHandshakeRTTMilliseconds[index] unsignedLongLongValue]))
            break;
    }
}

void nw_establishment_report_enumerate_resolutions(nw_establishment_report_t report, nw_report_resolution_enumerator_t enumerate_block)
{
    CharonNWEstablishmentReport *value = (CharonNWEstablishmentReport *)report;
    if (!value || !enumerate_block)
        return;
    for (CharonNWResolutionReport *resolution in value->_resolutions) {
        if (!enumerate_block(resolution->_source, resolution->_milliseconds, resolution->_endpointCount,
                             resolution->_successful, resolution->_preferred))
            break;
    }
}

#pragma mark - data transfer

nw_data_transfer_report_state_t nw_data_transfer_report_get_state(nw_data_transfer_report_t report)
{
    CharonNWDataTransferReport *value = (CharonNWDataTransferReport *)report;
    return value ? value->_state : (nw_data_transfer_report_state_t)0;
}

void nw_data_transfer_report_collect(nw_data_transfer_report_t report, dispatch_queue_t queue, nw_data_transfer_report_collect_block_t collect_block)
{
    CharonNWDataTransferReport *value = (CharonNWDataTransferReport *)report;
    if (!value)
        return;
    @synchronized(value) {
        if (value->_state == nw_data_transfer_report_state_collected)
            return;
        /* Outstanding becomes collecting now, and collected when the block is given it: asking twice
           is asking once, as the header says. */
        value->_state = nw_data_transfer_report_state_collecting;
    }
    if (!collect_block) {
        @synchronized(value) {
            value->_state = nw_data_transfer_report_state_collected;
        }
        return;
    }
    dispatch_async(queue ? queue : dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        @synchronized(value) {
            value->_state = nw_data_transfer_report_state_collected;
        }
        collect_block(report);
    });
}

/* Every value of a data transfer report answers 0 until the report is collected, which is what the
   header says of a report that is not collected. The counters themselves are already in the report:
   the connection wrote them when it gave the report out. */
static bool charon_collected(nw_data_transfer_report_t report, uint32_t path_index)
{
    CharonNWDataTransferReport *value = (CharonNWDataTransferReport *)report;
    if (!value || value->_state != nw_data_transfer_report_state_collected)
        return false;
    /* One path for a connection that is not multipath, so the path itself and NW_ALL_PATHS - which
       is what the header says that sums over paths means for a connection with one - are the same
       number, and any other index is no path at all. */
    return path_index == 0 || path_index == _nw_data_transfer_report_all_paths;
}

#define CHARON_REPORT_COUNT(report, path_index, field)                 \
    (charon_collected((report), (path_index)) ? ((CharonNWDataTransferReport *)(report))->field : 0)

nw_interface_t nw_data_transfer_report_copy_path_interface(nw_data_transfer_report_t report, uint32_t path_index)
{
    if (!charon_collected(report, path_index))
        return NULL;
    return ((CharonNWDataTransferReport *)report)->_interface;
}

uint64_t nw_data_transfer_report_get_duration_milliseconds(nw_data_transfer_report_t report)
{
    CharonNWDataTransferReport *value = (CharonNWDataTransferReport *)report;
    return charon_collected(report, 0) ? value->_durationMilliseconds : 0;
}

uint32_t nw_data_transfer_report_get_path_count(nw_data_transfer_report_t report)
{
    return charon_collected(report, 0) ? 1u : 0u;
}

uint64_t nw_data_transfer_report_get_sent_application_byte_count(nw_data_transfer_report_t report, uint32_t path_index)
{
    return CHARON_REPORT_COUNT(report, path_index, _sentApplicationBytes);
}

uint64_t nw_data_transfer_report_get_received_application_byte_count(nw_data_transfer_report_t report, uint32_t path_index)
{
    return CHARON_REPORT_COUNT(report, path_index, _receivedApplicationBytes);
}

uint64_t nw_data_transfer_report_get_sent_transport_byte_count(nw_data_transfer_report_t report, uint32_t path_index)
{
    return CHARON_REPORT_COUNT(report, path_index, _sentTransportBytes);
}

uint64_t nw_data_transfer_report_get_received_transport_byte_count(nw_data_transfer_report_t report, uint32_t path_index)
{
    return CHARON_REPORT_COUNT(report, path_index, _receivedTransportBytes);
}

uint64_t nw_data_transfer_report_get_sent_transport_retransmitted_byte_count(nw_data_transfer_report_t report, uint32_t path_index)
{
    return CHARON_REPORT_COUNT(report, path_index, _sentRetransmittedBytes);
}

uint64_t nw_data_transfer_report_get_received_transport_duplicate_byte_count(nw_data_transfer_report_t report, uint32_t path_index)
{
    return CHARON_REPORT_COUNT(report, path_index, _receivedDuplicateBytes);
}

uint64_t nw_data_transfer_report_get_received_transport_out_of_order_byte_count(nw_data_transfer_report_t report, uint32_t path_index)
{
    return CHARON_REPORT_COUNT(report, path_index, _receivedOutOfOrderBytes);
}

uint64_t nw_data_transfer_report_get_sent_ip_packet_count(nw_data_transfer_report_t report, uint32_t path_index)
{
    return CHARON_REPORT_COUNT(report, path_index, _sentIPPackets);
}

uint64_t nw_data_transfer_report_get_received_ip_packet_count(nw_data_transfer_report_t report, uint32_t path_index)
{
    return CHARON_REPORT_COUNT(report, path_index, _receivedIPPackets);
}

uint64_t nw_data_transfer_report_get_transport_smoothed_rtt_milliseconds(nw_data_transfer_report_t report, uint32_t path_index)
{
    return CHARON_REPORT_COUNT(report, path_index, _smoothedRTTMilliseconds);
}

uint64_t nw_data_transfer_report_get_transport_minimum_rtt_milliseconds(nw_data_transfer_report_t report, uint32_t path_index)
{
    return CHARON_REPORT_COUNT(report, path_index, _minimumRTTMilliseconds);
}

uint64_t nw_data_transfer_report_get_transport_rtt_variance(nw_data_transfer_report_t report, uint32_t path_index)
{
    return CHARON_REPORT_COUNT(report, path_index, _rttVarianceMilliseconds);
}
