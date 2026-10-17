#import "CharonGCSnapshot.h"
#import "CharonGC.h"

// The two V100 structures of iOS 7.0: the plain game's and the extended game's. They are one object
// because both symbols of each pair are first exported by the same release - release-split reads the
// built object and says so - and the extended game's V100 structure arrives with the plain game's.
//
// facts/GameController/Snapshots.md holds the measurements: a zeroed structure encodes as 36 bytes
// whose first four are 0001 2400 for the plain game and 60 bytes beginning 0001 3c00 for the extended
// one, and the two readers differ as the table there sets out.

NSData *NSDataFromGCGamepadSnapShotDataV100(GCGamepadSnapShotDataV100 *snapshotData)
{
    return charon_gc_snapshot_data(snapshotData, sizeof(GCGamepadSnapShotDataV100), CHARON_GCGAMEPAD_SNAPSHOT_VERSION_V100);
}

BOOL GCGamepadSnapShotDataV100FromNSData(GCGamepadSnapShotDataV100 *snapshotData, NSData *data)
{
    return charon_gc_snapshot_read(snapshotData, data, sizeof(GCGamepadSnapShotDataV100), charon_gc_accept_whole_structure);
}

NSData *NSDataFromGCExtendedGamepadSnapShotDataV100(GCExtendedGamepadSnapShotDataV100 *snapshotData)
{
    return charon_gc_snapshot_data(snapshotData, sizeof(GCExtendedGamepadSnapShotDataV100), GCExtendedGamepadSnapshotDataVersion1);
}

BOOL GCExtendedGamepadSnapShotDataV100FromNSData(GCExtendedGamepadSnapShotDataV100 *snapshotData, NSData *data)
{
    return charon_gc_snapshot_read(snapshotData, data, sizeof(GCExtendedGamepadSnapShotDataV100), charon_gc_accept_declared_size);
}

// GCGamepadSnapshot and the two saveSnapshot methods, all three first exported by iOS 7.0, so they are
// in this object and not in the 9.0 one. The extended method RETURNS GCExtendedGamepadSnapshot, which
// first appears at 9.0: the SDK's own GCExtendedGamepad.h declares the method at 7.0 with that return
// type, and the port reproduces the declaration rather than the chronology, so release-split is
// satisfied by the method's own first appearance at 7.0. GCExtendedGamepadSnapshot is forward-declared
// below for that reason and is not defined by this object.

@implementation GCGamepadSnapshot {
    NSData *_snapshotData;
}

@synthesize snapshotData = _snapshotData;

// The data is kept as given and the structure is decoded through the reader this object already ships,
// which is the one measured to refuse a whole-structure read of fewer than 36 bytes and a version of
// zero. Refusing that data is what the host does, so an init that cannot read it answers nil rather
// than building a snapshot whose values are not the ones in the data.
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
    [self charon_applyV100:&v100];
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

// The decoded values become the gamepad's own elements, so a snapshot read back answers the same
// numbers the data holds. The direction pad's two axes are two elements of their own - GCElements7.m
// gives a pad its xAxis and yAxis, and `charon_setValue:` is declared on GCControllerAxisInput, which
// a pad does not answer - so each value goes to the axis it names.
- (void)charon_applyV100:(GCGamepadSnapShotDataV100 *)v100
{
    GCControllerDirectionPad *dpad = (GCControllerDirectionPad *)[self charon_elementNamed:@"Direction Pad"];
    if (dpad != nil) {
        [(GCControllerAxisInput *)dpad.xAxis charon_setValue:v100->dpadX];
        [(GCControllerAxisInput *)dpad.yAxis charon_setValue:v100->dpadY];
    }
    NSDictionary *buttons = @{@"Button A": @(v100->buttonA), @"Button B": @(v100->buttonB),
                              @"Button X": @(v100->buttonX), @"Button Y": @(v100->buttonY),
                              @"Left Shoulder": @(v100->leftShoulder),
                              @"Right Shoulder": @(v100->rightShoulder)};
    for (NSString *name in buttons)
        [(GCControllerButtonInput *)[self charon_elementNamed:name]
            charon_update:(float)[buttons[name] floatValue]];
}

@end

// -saveSnapshot is what the SDK calls on a live gamepad, and it is the same two steps either way: read
// the current values into the structure, and hand the structure to the encoder this object ships. It is
// a category because the class itself is implemented in the 7.0 gamepad object and this object holds
// only the snapshot API.
// GCExtendedGamepadSnapshot is measured on the ladder at 7.0, the rung this object already
// carries, so the class belongs here rather than in an object of its own:
// `xmake l tools/cache-index/first-rung.lua GCExtendedGamepadSnapshot` answers 7.0. What it is,
// is the header's own - a profile of the extended game's elements that holds the values it was
// saved from and answers them again - so it holds the data and pushes it through the same
// accessors a live game uses, and the layout it reads is the packed structure
// GCExtendedGamepadSnapshot.h:41-78 documents.
//
// This also settles what -[GCExtendedGamepad saveSnapshot] was waiting for. That method is 7.0
// and returns this class, and a method's IMP emits an objc-class-ref for its return type; while
// the class sat at 9.0 the 6.1.3 band had nothing to satisfy that reference, which is the wall
// coordination/api-queue.md records. With the class here, at the same rung as the method, the
// reference is satisfied by this same object. The method is still absent and is not added here:
// that is one more change with its own measurement, and this commit is the split the gate asked
// for.
@implementation GCExtendedGamepadSnapshot {
    NSData *_snapshotData;
}

// The header's own property, at its own ownership: `atomic, copy`. @synthesize rather than
// @dynamic, because the port's build runs with -Werror=objc-missing-property-synthesis and a property
// with no accessor of its own is refused there.
@synthesize snapshotData = _snapshotData;

- (instancetype)initWithSnapshotData:(NSData *)data
{
    GCExtendedGamepadSnapshotData fields;
    memset(&fields, 0, sizeof(fields));
    if (!charon_gc_snapshot_read(&fields, data, sizeof(fields), charon_gc_accept_declared_size))
        return nil;
    self = [super init];
    if (self == nil)
        return nil;
    _snapshotData = [data copy];
    [self charon_applyExtended:&fields];
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

// The decoded values become the game's own elements, so a snapshot read back answers the same numbers
// the data holds. Every pad here writes through its own two axes - GCElements7.m gives a pad its xAxis
// and yAxis, and `charon_setValue:` is declared on GCControllerAxisInput, which a pad does not answer.
- (void)charon_applyExtended:(GCExtendedGamepadSnapshotData *)fields
{
    GCControllerDirectionPad *dpad = (GCControllerDirectionPad *)[self charon_elementNamed:@"Direction Pad"];
    if (dpad != nil) {
        [(GCControllerAxisInput *)dpad.xAxis charon_setValue:fields->dpadX];
        [(GCControllerAxisInput *)dpad.yAxis charon_setValue:fields->dpadY];
    }
    GCControllerDirectionPad *left = (GCControllerDirectionPad *)[self charon_elementNamed:@"Left Thumbstick"];
    if (left != nil) {
        [(GCControllerAxisInput *)left.xAxis charon_setValue:fields->leftThumbstickX];
        [(GCControllerAxisInput *)left.yAxis charon_setValue:fields->leftThumbstickY];
    }
    GCControllerDirectionPad *right = (GCControllerDirectionPad *)[self charon_elementNamed:@"Right Thumbstick"];
    if (right != nil) {
        [(GCControllerAxisInput *)right.xAxis charon_setValue:fields->rightThumbstickX];
        [(GCControllerAxisInput *)right.yAxis charon_setValue:fields->rightThumbstickY];
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
        [(GCControllerButtonInput *)[self charon_elementNamed:name]
            charon_update:(float)[buttons[name] floatValue]];
}

@end

// -[GCExtendedGamepad saveSnapshot] is 7.0 (GCExtendedGamepad.h:65) and returns
// GCExtendedGamepadSnapshot, which first-rung.lua also places at 7.0, so both live in this object and
// the method's IMP has its class-ref answered inside it. That is the whole of what the wall recorded
// in coordination/api-queue.md was: the method's IMP emits an objc-class-ref for its return type, and
// while the class sat at 9.0 the 6.1.3 band had no 9.0 object to satisfy it. Measured on this object,
// before and after, with nm -u: before it names GCExtendedGamepad, GCGamepad, NSData, NSDictionary and
// NSNumber; after, those five plus GCExtendedGamepadSnapshot - which this same object defines, so the
// reference resolves here and the dylib links.
//
// It is the same two steps as the plain game's method below: read the current values into the
// structure, hand the structure to the encoder this file's header holds. The values are the extended
// game's own elements, and the layout is the structure GCExtendedGamepadSnapshot.h:41-78 documents.
@implementation GCExtendedGamepad (CharonGCSnapshot7)

- (GCExtendedGamepadSnapshot *)saveSnapshot
{
    GCExtendedGamepadSnapshotData fields;
    memset(&fields, 0, sizeof(fields));
    GCControllerDirectionPad *dpad = (GCControllerDirectionPad *)[self charon_elementNamed:@"Direction Pad"];
    fields.dpadX = charon_gc_pad_axis(dpad, @selector(xAxis));
    fields.dpadY = charon_gc_pad_axis(dpad, @selector(yAxis));
    // The two thumbsticks' four axes, read through each stick's own axes.
    GCControllerDirectionPad *left = (GCControllerDirectionPad *)[self charon_elementNamed:@"Left Thumbstick"];
    if (left != nil) {
        fields.leftThumbstickX = charon_gc_pad_axis(left, @selector(xAxis));
        fields.leftThumbstickY = charon_gc_pad_axis(left, @selector(yAxis));
    }
    GCControllerDirectionPad *right = (GCControllerDirectionPad *)[self charon_elementNamed:@"Right Thumbstick"];
    if (right != nil) {
        fields.rightThumbstickX = charon_gc_pad_axis(right, @selector(xAxis));
        fields.rightThumbstickY = charon_gc_pad_axis(right, @selector(yAxis));
    }
    // The header's own byte 60: the structure says the thumbsticks act as buttons, and the host writes
    // 01 for a controller nothing has touched, which is what a zeroed structure does not. It is set
    // from the profile's own elements - a stick that carries its button is one that can be pressed -
    // and not to a constant, so a profile without them encodes 0.
    fields.supportsClickableThumbsticks =
        [self charon_elementNamed:@"Left Thumbstick Button"] != nil
        && [self charon_elementNamed:@"Right Thumbstick Button"] != nil;
    // A button's own value, and the trigger's: the two are read here and written into the structure
    // rather than being the zero a memset leaves, so a controller with a held button encodes it.
    fields.buttonA = charon_gc_button_value([self charon_elementNamed:@"Button A"]);
    fields.buttonB = charon_gc_button_value([self charon_elementNamed:@"Button B"]);
    fields.buttonX = charon_gc_button_value([self charon_elementNamed:@"Button X"]);
    fields.buttonY = charon_gc_button_value([self charon_elementNamed:@"Button Y"]);
    fields.leftShoulder = charon_gc_button_value([self charon_elementNamed:@"Left Shoulder"]);
    fields.rightShoulder = charon_gc_button_value([self charon_elementNamed:@"Right Shoulder"]);
    fields.leftTrigger = charon_gc_button_value([self charon_elementNamed:@"Left Trigger"]);
    fields.rightTrigger = charon_gc_button_value([self charon_elementNamed:@"Right Trigger"]);
    fields.leftThumbstickButton = charon_gc_button_value([self charon_elementNamed:@"Left Thumbstick Button"]);
    fields.rightThumbstickButton = charon_gc_button_value([self charon_elementNamed:@"Right Thumbstick Button"]);
    return [[GCExtendedGamepadSnapshot alloc]
               initWithSnapshotData:charon_gc_snapshot_data(&fields, sizeof(fields),
                                                            GCExtendedGamepadSnapshotDataVersion2)];
}

@end

@implementation GCGamepad (CharonGCSnapshot7)

- (GCGamepadSnapshot *)saveSnapshot
{
    GCGamepadSnapShotDataV100 v100;
    memset(&v100, 0, sizeof(v100));
    v100.version = CHARON_GCGAMEPAD_SNAPSHOT_VERSION_V100;
    v100.size = (uint16_t)sizeof(v100);
    GCControllerDirectionPad *dpad = (GCControllerDirectionPad *)[self charon_elementNamed:@"Direction Pad"];
    v100.dpadX = charon_gc_pad_axis(dpad, @selector(xAxis));
    v100.dpadY = charon_gc_pad_axis(dpad, @selector(yAxis));
    v100.buttonA = charon_gc_button_value([self charon_elementNamed:@"Button A"]);
    v100.buttonB = charon_gc_button_value([self charon_elementNamed:@"Button B"]);
    v100.buttonX = charon_gc_button_value([self charon_elementNamed:@"Button X"]);
    v100.buttonY = charon_gc_button_value([self charon_elementNamed:@"Button Y"]);
    v100.leftShoulder = charon_gc_button_value([self charon_elementNamed:@"Left Shoulder"]);
    v100.rightShoulder = charon_gc_button_value([self charon_elementNamed:@"Right Shoulder"]);
    return [[GCGamepadSnapshot alloc] initWithSnapshotData:NSDataFromGCGamepadSnapShotDataV100(&v100)];
}

@end

