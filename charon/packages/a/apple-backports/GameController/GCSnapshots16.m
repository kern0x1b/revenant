#import "CharonGCSnapshot.h"

// The current structure of each game and the two version constants, all of which the ladder first
// exports at 16.0 - the extended game's structure grew its clickable-thumbstick fields at 12.1 and the
// micro game's came with its snapshot at 9.0, but the symbols these four functions define are first
// exported at 16.0, which is the release release-split reads out of the built object. This is the
// tree's own rule: GCConstants16.m carries what 16.0 brought.
//
// The two constants are the header's own enumerations: GCExtendedGamepadSnapshotDataVersion2, which
// is 0x0101, and GCMicroGamepadSnapshotDataVersion1, which is 0x0100. Nothing reads them out of the
// host at run time - the values are the ones the header states, taken at compile time from the very
// enumeration it names.

const GCExtendedGamepadSnapshotDataVersion GCCurrentExtendedGamepadSnapshotDataVersion = GCExtendedGamepadSnapshotDataVersion2;
const GCMicroGamepadSnapshotDataVersion GCCurrentMicroGamepadSnapshotDataVersion = GCMicroGamepadSnapshotDataVersion1;

NSData *NSDataFromGCExtendedGamepadSnapshotData(GCExtendedGamepadSnapshotData *snapshotData)
{
    return charon_gc_snapshot_data(snapshotData, sizeof(GCExtendedGamepadSnapshotData), GCCurrentExtendedGamepadSnapshotDataVersion);
}

BOOL GCExtendedGamepadSnapshotDataFromNSData(GCExtendedGamepadSnapshotData *snapshotData, NSData *data)
{
    return charon_gc_snapshot_read(snapshotData, data, sizeof(GCExtendedGamepadSnapshotData), charon_gc_accept_declared_size);
}

NSData *NSDataFromGCMicroGamepadSnapshotData(GCMicroGamepadSnapshotData *snapshotData)
{
    return charon_gc_snapshot_data(snapshotData, sizeof(GCMicroGamepadSnapshotData), GCCurrentMicroGamepadSnapshotDataVersion);
}

BOOL GCMicroGamepadSnapshotDataFromNSData(GCMicroGamepadSnapshotData *snapshotData, NSData *data)
{
    return charon_gc_snapshot_read(snapshotData, data, sizeof(GCMicroGamepadSnapshotData), charon_gc_accept_declared_size);
}
