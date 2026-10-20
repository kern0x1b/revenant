#import "RevenantGCSnapshot.h"
#import "RevenantGC.h"

NSData *NSDataFromGCMicroGamepadSnapShotDataV100(GCMicroGamepadSnapShotDataV100 *snapshotData)
{
    return revenant_gc_snapshot_data(snapshotData, sizeof(GCMicroGamepadSnapShotDataV100), GCMicroGamepadSnapshotDataVersion1);
}

BOOL GCMicroGamepadSnapShotDataV100FromNSData(GCMicroGamepadSnapShotDataV100 *snapshotData, NSData *data)
{
    return revenant_gc_snapshot_read(snapshotData, data, sizeof(GCMicroGamepadSnapShotDataV100), revenant_gc_accept_declared_size);
}

@implementation GCMicroGamepadSnapshot {
    NSData *_snapshotData;
}

@synthesize snapshotData = _snapshotData;

- (instancetype)initWithSnapshotData:(NSData *)data
{
    GCMicroGamepadSnapshotData fields;
    memset(&fields, 0, sizeof(fields));
    if (!revenant_gc_snapshot_read(&fields, data, sizeof(fields), revenant_gc_accept_declared_size))
        return nil;
    self = [super init];
    if (self == nil)
        return nil;
    _snapshotData = [data copy];
    [self revenant_applyMicro:&fields];
    return self;
}

- (instancetype)initWithController:(GCController *)controller snapshotData:(NSData *)data
{
    self = [self initWithSnapshotData:data];
    if (self == nil)
        return nil;
    [self revenant_setController:controller];
    return self;
}

- (void)revenant_applyMicro:(GCMicroGamepadSnapshotData *)fields
{
    GCControllerDirectionPad *dpad = (GCControllerDirectionPad *)[self revenant_elementNamed:@"Direction Pad"];
    if (dpad != nil) {
        [(GCControllerAxisInput *)dpad.xAxis revenant_setValue:fields->dpadX];
        [(GCControllerAxisInput *)dpad.yAxis revenant_setValue:fields->dpadY];
    }
    [(GCControllerButtonInput *)[self revenant_elementNamed:@"Button A"] revenant_update:fields->buttonA];
    [(GCControllerButtonInput *)[self revenant_elementNamed:@"Button X"] revenant_update:fields->buttonX];
}

@end

@implementation GCMicroGamepad (RevenantGCSnapshot9)

- (GCMicroGamepadSnapshot *)saveSnapshot
{
    GCMicroGamepadSnapshotData fields;
    memset(&fields, 0, sizeof(fields));
    GCControllerDirectionPad *dpad = (GCControllerDirectionPad *)[self revenant_elementNamed:@"Direction Pad"];
    fields.dpadX = revenant_gc_pad_axis(dpad, @selector(xAxis));
    fields.dpadY = revenant_gc_pad_axis(dpad, @selector(yAxis));
    fields.buttonA = revenant_gc_button_value([self revenant_elementNamed:@"Button A"]);
    fields.buttonX = revenant_gc_button_value([self revenant_elementNamed:@"Button X"]);
    return [[GCMicroGamepadSnapshot alloc]
               initWithSnapshotData:revenant_gc_snapshot_data(&fields, sizeof(fields),
                                                            GCMicroGamepadSnapshotDataVersion1)];
}

@end
