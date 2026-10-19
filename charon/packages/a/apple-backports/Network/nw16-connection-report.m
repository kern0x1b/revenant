/*
 * The two report calls of iOS 13, which the 16.0 cache is the first to export - so an object of their
 * own, the rest of the connection being iOS 12 (tools/release-split.lua, which is what says so).
 *
 * The establishment report is the connection's own: the time from its first start to the state it
 * reached, the attempts before it, the protocols of its stack and the address it settled on. The data
 * transfer report is what it has moved since it was made, with the round trip times the kernel's own
 * TCP_CONNECTION_INFO holds. Both are filled when a program asks for them and read back with the
 * accessors of NWObjects.md.
 */

#import "CharonNW.h"
#import "CharonNWSupport.h"

#include <netinet/in.h>
#include <string.h>

/* What the connection reports, filled in by the file that has it: a class method would be one more
   symbol, and the connection's own file is the one place that knows. */
nw_establishment_report_t CharonNWConnectionEstablishmentReport(nw_connection_t connection);
nw_data_transfer_report_t CharonNWConnectionDataTransferReport(nw_connection_t connection);

void nw_connection_access_establishment_report(nw_connection_t connection, dispatch_queue_t queue,
                                               nw_establishment_report_access_block_t access_block)
{
    if (!connection)
        return;
    nw_establishment_report_t report = access_block ? CharonNWConnectionEstablishmentReport(connection) : NULL;
    if (!access_block)
        return;
    dispatch_async(queue ?: dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        access_block(report);
    });
}

nw_data_transfer_report_t nw_connection_create_new_data_transfer_report(nw_connection_t connection)
{
    return connection ? CharonNWConnectionDataTransferReport(connection) : NULL;
}
