#import "RevenantGCSnapshot.h"
#import "RevenantGC.h"

NSData *NSDataFromGCGamepadSnapShotDataV100(GCGamepadSnapShotDataV100 *snapshotData)
{
    return revenant_gc_snapshot_data(snapshotData, sizeof(GCGamepadSnapShotDataV100), REVENANT_GCGAMEPAD_SNAPSHOT_VERSION_V100);
}

BOOL GCGamepadSnapShotDataV100FromNSData(GCGamepadSnapShotDataV100 *snapshotData, NSData *data)
{
    return revenant_gc_snapshot_read(snapshotData, data, sizeof(GCGamepadSnapShotDataV100), revenant_gc_accept_whole_structure);
}

NSData *NSDataFromGCExtendedGamepadSnapShotDataV100(GCExtendedGamepadSnapShotDataV100 *snapshotData)
{
    return revenant_gc_snapshot_data(snapshotData, sizeof(GCExtendedGamepadSnapShotDataV100), GCExtendedGamepadSnapshotDataVersion1);
}

BOOL GCExtendedGamepadSnapShotDataV100FromNSData(GCExtendedGamepadSnapShotDataV100 *snapshotData, NSData *data)
{
    return revenant_gc_snapshot_read(snapshotData, data, sizeof(GCExtendedGamepadSnapShotDataV100), revenant_gc_accept_declared_size);
}

@implementation GCGamepadSnapshot {
    NSData *_snapshotData;
}

@synthesize snapshotData = _snapshotData;

- (instancetype)initWithSnapshotData:(NSData *)data
{
    GCGamepadSnapShotDataV100 v100;
    memset(&v100, 0, sizeof(v100));
    if (!GCGamepadSnapShotDataV100FromNSData(&v100, data))
        return nil;
    self = [super init];
    if (self == nil)
        return nil;
    _snapshotData = [data copy];
    [self revenant_applyV100:&v100];
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

- (void)revenant_applyV100:(GCGamepadSnapShotDataV100 *)v100
{
    GCControllerDirectionPad *dpad = (GCControllerDirectionPad *)[self revenant_elementNamed:@"Direction Pad"];
    if (dpad != nil) {
        [(GCControllerAxisInput *)dpad.xAxis revenant_setValue:v100->dpadX];
        [(GCControllerAxisInput *)dpad.yAxis revenant_setValue:v100->dpadY];
    }
    NSDictionary *buttons = @{@"Button A": @(v100->buttonA), @"Button B": @(v100->buttonB),
                              @"Button X": @(v100->buttonX), @"Button Y": @(v100->buttonY),
                              @"Left Shoulder": @(v100->leftShoulder),
                              @"Right Shoulder": @(v100->rightShoulder)};
    for (NSString *name in buttons)
        [(GCControllerButtonInput *)[self revenant_elementNamed:name]
            revenant_update:(float)[buttons[name] floatValue]];
}

@end

@implementation GCExtendedGamepadSnapshot {
    NSData *_snapshotData;
}

@synthesize snapshotData = _snapshotData;

- (instancetype)initWithSnapshotData:(NSData *)data
{
    GCExtendedGamepadSnapshotData fields;
    memset(&fields, 0, sizeof(fields));
    if (!revenant_gc_snapshot_read(&fields, data, sizeof(fields), revenant_gc_accept_declared_size))
        return nil;
    self = [super init];
    if (self == nil)
        return nil;
    _snapshotData = [data copy];
    [self revenant_applyExtended:&fields];
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

- (void)revenant_applyExtended:(GCExtendedGamepadSnapshotData *)fields
{
    GCControllerDirectionPad *dpad = (GCControllerDirectionPad *)[self revenant_elementNamed:@"Direction Pad"];
    if (dpad != nil) {
        [(GCControllerAxisInput *)dpad.xAxis revenant_setValue:fields->dpadX];
        [(GCControllerAxisInput *)dpad.yAxis revenant_setValue:fields->dpadY];
    }
    GCControllerDirectionPad *left = (GCControllerDirectionPad *)[self revenant_elementNamed:@"Left Thumbstick"];
    if (left != nil) {
        [(GCControllerAxisInput *)left.xAxis revenant_setValue:fields->leftThumbstickX];
        [(GCControllerAxisInput *)left.yAxis revenant_setValue:fields->leftThumbstickY];
    }
    GCControllerDirectionPad *right = (GCControllerDirectionPad *)[self revenant_elementNamed:@"Right Thumbstick"];
    if (right != nil) {
        [(GCControllerAxisInput *)right.xAxis revenant_setValue:fields->rightThumbstickX];
        [(GCControllerAxisInput *)right.yAxis revenant_setValue:fields->rightThumbstickY];
    }
    NSDictionary *buttons = @{@"Button A": @(fields->buttonA), @"Button B": @(fields->buttonB),
                              @"Button X": @(fields->buttonX), @"Button Y": @(fields->buttonY),
                              @"Left Shoulder": @(fields->leftShoulder),
                              @"Right Shoulder": @(fields->rightShoulder),
                              @"Left Trigger": @(fields->leftTrigger),
                              @"Right Trigger": @(fields->rightTrigger),
                              @"Left Thumbstick Button": @(fields->leftThumbstickButton),
                              @"Right Thumbstick Button": @(fields->rightThumbstickButton)};
    for (NSString *name in buttons)
        [(GCControllerButtonInput *)[self revenant_elementNamed:name]
            revenant_update:(float)[buttons[name] floatValue]];
}

@end

@implementation GCExtendedGamepad (RevenantGCSnapshot7)

- (GCExtendedGamepadSnapshot *)saveSnapshot
{
    GCExtendedGamepadSnapshotData fields;
    memset(&fields, 0, sizeof(fields));
    GCControllerDirectionPad *dpad = (GCControllerDirectionPad *)[self revenant_elementNamed:@"Direction Pad"];
    fields.dpadX = revenant_gc_pad_axis(dpad, @selector(xAxis));
    fields.dpadY = revenant_gc_pad_axis(dpad, @selector(yAxis));
    GCControllerDirectionPad *left = (GCControllerDirectionPad *)[self revenant_elementNamed:@"Left Thumbstick"];
    if (left != nil) {
        fields.leftThumbstickX = revenant_gc_pad_axis(left, @selector(xAxis));
        fields.leftThumbstickY = revenant_gc_pad_axis(left, @selector(yAxis));
    }
    GCControllerDirectionPad *right = (GCControllerDirectionPad *)[self revenant_elementNamed:@"Right Thumbstick"];
    if (right != nil) {
        fields.rightThumbstickX = revenant_gc_pad_axis(right, @selector(xAxis));
        fields.rightThumbstickY = revenant_gc_pad_axis(right, @selector(yAxis));
    }
    fields.supportsClickableThumbsticks =
        [self revenant_elementNamed:@"Left Thumbstick Button"] != nil
        && [self revenant_elementNamed:@"Right Thumbstick Button"] != nil;
    fields.buttonA = revenant_gc_button_value([self revenant_elementNamed:@"Button A"]);
    fields.buttonB = revenant_gc_button_value([self revenant_elementNamed:@"Button B"]);
    fields.buttonX = revenant_gc_button_value([self revenant_elementNamed:@"Button X"]);
    fields.buttonY = revenant_gc_button_value([self revenant_elementNamed:@"Button Y"]);
    fields.leftShoulder = revenant_gc_button_value([self revenant_elementNamed:@"Left Shoulder"]);
    fields.rightShoulder = revenant_gc_button_value([self revenant_elementNamed:@"Right Shoulder"]);
    fields.leftTrigger = revenant_gc_button_value([self revenant_elementNamed:@"Left Trigger"]);
    fields.rightTrigger = revenant_gc_button_value([self revenant_elementNamed:@"Right Trigger"]);
    fields.leftThumbstickButton = revenant_gc_button_value([self revenant_elementNamed:@"Left Thumbstick Button"]);
    fields.rightThumbstickButton = revenant_gc_button_value([self revenant_elementNamed:@"Right Thumbstick Button"]);
    return [[GCExtendedGamepadSnapshot alloc]
               initWithSnapshotData:revenant_gc_snapshot_data(&fields, sizeof(fields),
                                                            GCExtendedGamepadSnapshotDataVersion2)];
}

@end

@implementation GCGamepad (RevenantGCSnapshot7)

- (GCGamepadSnapshot *)saveSnapshot
{
    GCGamepadSnapShotDataV100 v100;
    memset(&v100, 0, sizeof(v100));
    v100.version = REVENANT_GCGAMEPAD_SNAPSHOT_VERSION_V100;
    v100.size = (uint16_t)sizeof(v100);
    GCControllerDirectionPad *dpad = (GCControllerDirectionPad *)[self revenant_elementNamed:@"Direction Pad"];
    v100.dpadX = revenant_gc_pad_axis(dpad, @selector(xAxis));
    v100.dpadY = revenant_gc_pad_axis(dpad, @selector(yAxis));
    v100.buttonA = revenant_gc_button_value([self revenant_elementNamed:@"Button A"]);
    v100.buttonB = revenant_gc_button_value([self revenant_elementNamed:@"Button B"]);
    v100.buttonX = revenant_gc_button_value([self revenant_elementNamed:@"Button X"]);
    v100.buttonY = revenant_gc_button_value([self revenant_elementNamed:@"Button Y"]);
    v100.leftShoulder = revenant_gc_button_value([self revenant_elementNamed:@"Left Shoulder"]);
    v100.rightShoulder = revenant_gc_button_value([self revenant_elementNamed:@"Right Shoulder"]);
    return [[GCGamepadSnapshot alloc] initWithSnapshotData:NSDataFromGCGamepadSnapShotDataV100(&v100)];
}

@end
