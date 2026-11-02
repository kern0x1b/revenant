#include "../revenant_impl.h"
#import "RevenantGCSnapshot.h"

const GCExtendedGamepadSnapshotDataVersion BACKPORT_IMPL(GCCurrentExtendedGamepadSnapshotDataVersion) = GCExtendedGamepadSnapshotDataVersion2;
const GCMicroGamepadSnapshotDataVersion BACKPORT_IMPL(GCCurrentMicroGamepadSnapshotDataVersion) = GCMicroGamepadSnapshotDataVersion1;

NSData *BACKPORT_IMPL(NSDataFromGCExtendedGamepadSnapshotData)(GCExtendedGamepadSnapshotData *snapshotData)
{
    return revenant_gc_snapshot_data(snapshotData, sizeof(GCExtendedGamepadSnapshotData), GCCurrentExtendedGamepadSnapshotDataVersion);
}

BOOL BACKPORT_IMPL(GCExtendedGamepadSnapshotDataFromNSData)(GCExtendedGamepadSnapshotData *snapshotData, NSData *data)
{
    return revenant_gc_snapshot_read(snapshotData, data, sizeof(GCExtendedGamepadSnapshotData), revenant_gc_accept_declared_size);
}

NSData *BACKPORT_IMPL(NSDataFromGCMicroGamepadSnapshotData)(GCMicroGamepadSnapshotData *snapshotData)
{
    return revenant_gc_snapshot_data(snapshotData, sizeof(GCMicroGamepadSnapshotData), GCCurrentMicroGamepadSnapshotDataVersion);
}

BOOL BACKPORT_IMPL(GCMicroGamepadSnapshotDataFromNSData)(GCMicroGamepadSnapshotData *snapshotData, NSData *data)
{
    return revenant_gc_snapshot_read(snapshotData, data, sizeof(GCMicroGamepadSnapshotData), revenant_gc_accept_declared_size);
}
