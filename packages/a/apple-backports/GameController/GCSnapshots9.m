#import "CharonGCSnapshot.h"
#import "CharonGC.h"

// The micro game's V100 structure of iOS 9.0, whose symbols the ladder first exports at 10.0.1 -
// GCMicroGamepad9.m is the tree's own object for the same reason - so this one carries the release
// it is named for and not the release its symbols arrive in.
//
// facts/GameController/Snapshots.md holds the measurements: a zeroed structure encodes as 20 bytes
// beginning 0001 1400, and the reader takes 20 bytes and refuses 21.

NSData *NSDataFromGCMicroGamepadSnapShotDataV100(GCMicroGamepadSnapShotDataV100 *snapshotData)
{
    return charon_gc_snapshot_data(snapshotData, sizeof(GCMicroGamepadSnapShotDataV100), GCMicroGamepadSnapshotDataVersion1);
}

BOOL GCMicroGamepadSnapShotDataV100FromNSData(GCMicroGamepadSnapShotDataV100 *snapshotData, NSData *data)
{
    return charon_gc_snapshot_read(snapshotData, data, sizeof(GCMicroGamepadSnapShotDataV100), charon_gc_accept_declared_size);
}

// The micro game's snapshot class is measured on the ladder at 10.0.1 - the same rung as the
// V100 pair above, which is why this is the object it belongs in:
// `xmake l tools/cache-index/first-rung.lua GCMicroGamepadSnapshot` answers 10.0.1. The class is a
// profile of the micro game's elements holding the values it was saved from, and its structure has
// four fields - the direction pad's two axes and two buttons - which is what
// GCMicroGamepadSnapshot.h:39-52 documents.
//
// -saveSnapshot is the SDK's own call on a live game, and the same two steps either way: read the
// current values into the structure, hand the structure to the encoder above. Its row is carried at
// 10.0.1 rather than the 9.0 the SDK header's deprecation range starts at, because
// measured_names() answers NONE for a method and the ladder's answer for the class it returns is
// the floor it cannot precede.
@implementation GCMicroGamepadSnapshot {
    NSData *_snapshotData;
}

@synthesize snapshotData = _snapshotData;

- (instancetype)initWithSnapshotData:(NSData *)data
{
    GCMicroGamepadSnapshotData fields;
    memset(&fields, 0, sizeof(fields));
    if (!charon_gc_snapshot_read(&fields, data, sizeof(fields), charon_gc_accept_declared_size))
        return nil;
    self = [super init];
    if (self == nil)
        return nil;
    _snapshotData = [data copy];
    [self charon_applyMicro:&fields];
    return self;
}

- (instancetype)initWithController:(GCController *)controller snapshotData:(NSData *)data
{
    self = [self initWithSnapshotData:data];
    if (self == nil)
        return nil;
    [self charon_setController:controller];
    return self;
}

// The micro structure has four fields and the micro profile has the four elements they name, so this
// is the direction pad's two axes and two buttons and nothing else.
- (void)charon_applyMicro:(GCMicroGamepadSnapshotData *)fields
{
    GCControllerDirectionPad *dpad = (GCControllerDirectionPad *)[self charon_elementNamed:@"Direction Pad"];
    if (dpad != nil) {
        [(GCControllerAxisInput *)dpad.xAxis charon_setValue:fields->dpadX];
        [(GCControllerAxisInput *)dpad.yAxis charon_setValue:fields->dpadY];
    }
    [(GCControllerButtonInput *)[self charon_elementNamed:@"Button A"] charon_update:fields->buttonA];
    [(GCControllerButtonInput *)[self charon_elementNamed:@"Button X"] charon_update:fields->buttonX];
}

@end

// -saveSnapshot is what the SDK calls on a live game, and it is the same two steps either way: read
// the current values into the structure, and hand the structure to the encoder this file's header
// holds. It is a category because the class itself is implemented in GCMicroGamepad9.m and this object
// carries the micro game's snapshot API, not the micro game.
//
// Only the micro game gets one here. The extended game's own method is 7.0 and returns a class that
// is now carried in GCSnapshots7.m at the same rung, so that pair is no longer split - see the note
// there. This object does not take it: GCExtendedGamepad is 7.0 and putting its 7.0 method beside
// this file's 10.0.1 names is exactly the two-releases-in-one-object the gate refuses.
@implementation GCMicroGamepad (CharonGCSnapshot9)

- (GCMicroGamepadSnapshot *)saveSnapshot
{
    GCMicroGamepadSnapshotData fields;
    memset(&fields, 0, sizeof(fields));
    GCControllerDirectionPad *dpad = (GCControllerDirectionPad *)[self charon_elementNamed:@"Direction Pad"];
    fields.dpadX = charon_gc_pad_axis(dpad, @selector(xAxis));
    fields.dpadY = charon_gc_pad_axis(dpad, @selector(yAxis));
    fields.buttonA = charon_gc_button_value([self charon_elementNamed:@"Button A"]);
    fields.buttonX = charon_gc_button_value([self charon_elementNamed:@"Button X"]);
    return [[GCMicroGamepadSnapshot alloc]
               initWithSnapshotData:charon_gc_snapshot_data(&fields, sizeof(fields),
                                                            GCMicroGamepadSnapshotDataVersion1)];
}

@end
