#import "RevenantGCSnapshot.h"

const GCExtendedGamepadSnapshotDataVersion GCCurrentExtendedGamepadSnapshotDataVersion = GCExtendedGamepadSnapshotDataVersion2;
const GCMicroGamepadSnapshotDataVersion GCCurrentMicroGamepadSnapshotDataVersion = GCMicroGamepadSnapshotDataVersion1;

NSData *NSDataFromGCExtendedGamepadSnapshotData(GCExtendedGamepadSnapshotData *snapshotData)
{
    return revenant_gc_snapshot_data(snapshotData, sizeof(GCExtendedGamepadSnapshotData), GCCurrentExtendedGamepadSnapshotDataVersion);
}

BOOL GCExtendedGamepadSnapshotDataFromNSData(GCExtendedGamepadSnapshotData *snapshotData, NSData *data)
{
    return revenant_gc_snapshot_read(snapshotData, data, sizeof(GCExtendedGamepadSnapshotData), revenant_gc_accept_declared_size);
}

NSData *NSDataFromGCMicroGamepadSnapshotData(GCMicroGamepadSnapshotData *snapshotData)
{
    return revenant_gc_snapshot_data(snapshotData, sizeof(GCMicroGamepadSnapshotData), GCCurrentMicroGamepadSnapshotDataVersion);
}

BOOL GCMicroGamepadSnapshotDataFromNSData(GCMicroGamepadSnapshotData *snapshotData, NSData *data)
{
    return revenant_gc_snapshot_read(snapshotData, data, sizeof(GCMicroGamepadSnapshotData), revenant_gc_accept_declared_size);
}
