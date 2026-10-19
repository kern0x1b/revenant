#import "RevenantNW.h"
#import "RevenantNWSupport.h"

#include <netinet/in.h>
#include <string.h>

nw_establishment_report_t RevenantNWConnectionEstablishmentReport(nw_connection_t connection);
nw_data_transfer_report_t RevenantNWConnectionDataTransferReport(nw_connection_t connection);

void nw_connection_access_establishment_report(nw_connection_t connection, dispatch_queue_t queue,
                                               nw_establishment_report_access_block_t access_block)
{
    if (!connection)
        return;
    nw_establishment_report_t report = access_block ? RevenantNWConnectionEstablishmentReport(connection) : NULL;
    if (!access_block)
        return;
    dispatch_async(queue ?: dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        access_block(report);
    });
}

nw_data_transfer_report_t nw_connection_create_new_data_transfer_report(nw_connection_t connection)
{
    return connection ? RevenantNWConnectionDataTransferReport(connection) : NULL;
}
