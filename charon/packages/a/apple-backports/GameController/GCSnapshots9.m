#import "CharonGCSnapshot.h"
#import "CharonGC.h"

NSData *NSDataFromGCMicroGamepadSnapShotDataV100(GCMicroGamepadSnapShotDataV100 *snapshotData)
{
    return charon_gc_snapshot_data(snapshotData, sizeof(GCMicroGamepadSnapShotDataV100), GCMicroGamepadSnapshotDataVersion1);
}

BOOL GCMicroGamepadSnapShotDataV100FromNSData(GCMicroGamepadSnapShotDataV100 *snapshotData, NSData *data)
{
    return charon_gc_snapshot_read(snapshotData, data, sizeof(GCMicroGamepadSnapShotDataV100), charon_gc_accept_declared_size);
}

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
