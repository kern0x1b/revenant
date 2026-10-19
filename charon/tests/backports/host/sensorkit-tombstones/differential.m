// The port's own -[NSString sr_sensorForDeletionRecordsFromSensor], printed from its own LINKED category.
//
// This is a CATEGORY ON NSString, so the port's category and the host's own one would replace one
// another if they were in one process: whichever loaded last would win and the comparison would be the
// port's answers checked against the port. The two sides are therefore in two processes - this one links
// packages/a/apple-backports/SensorKit/NSString+SensorKit14.m and prints what the port holds, and
// read-host.m opens the host's framework and prints what it holds - and compare.py puts the two side by
// side over one list of inputs that both walk.
//
// The list is the whole of the argument: every sensor name the port carries, every one of them already
// carrying the suffix, an empty string, a word that is not a sensor at all, case variants and
// whitespace variants. A rule that were "append the suffix" and one that were "append the suffix unless
// it is already there" differ on exactly the second group, so a list without it could not tell them
// apart.
//
// Nothing here links SensorKit.framework. That is deliberate: with the framework linked, the host's own
// category would be in this image too, and this process would print the host's answers and call them the
// port's.
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

int main(void)
{
    setvbuf(stdout, NULL, _IOLBF, 0);

    // The port's twenty-two sensor identifiers, spelled the way CharonSensorKitNames.h spells them and
    // SensorKitNames14.m spells them. They are literals rather than externs so this file links only the
    // port's category and nothing else; a reader checking them against the port's own header is
    // sensorkit-names' job, over 57 names, and this harness does not duplicate it.
    NSArray *sensors = @[
        @"com.apple.SensorKit.motion.accelerometer", @"com.apple.SensorKit.motion.gyroscope",
        @"com.apple.SensorKit.als", @"com.apple.SensorKit.visits", @"com.apple.SensorKit.pedometer.data",
        @"com.apple.SensorKit.deviceUsageReport", @"com.apple.SensorKit.keyboardMetrics",
        @"com.apple.SensorKit.messagesUsageReport", @"com.apple.SensorKit.phoneUsageReport",
        @"com.apple.SensorKit.onWristState", @"com.apple.SensorKit.speechMetrics.siri",
        @"com.apple.SensorKit.speechMetrics.telephony", @"com.apple.SensorKit.ambientPressure",
        @"com.apple.SensorKit.mediaEvents", @"com.apple.SensorKit.wristTemperature",
        @"com.apple.SensorKit.heart.rate", @"com.apple.SensorKit.faceMetrics",
        @"com.apple.SensorKit.odometer", @"com.apple.SensorKit.ECG", @"com.apple.SensorKit.PPG",
        @"com.apple.SensorKit.hearing.acousticSettings", @"com.apple.SensorKit.sleep.sessions",
    ];

    NSMutableArray *inputs = [NSMutableArray array];
    for (NSString *name in sensors) {
        [inputs addObject:name];
        [inputs addObject:[name stringByAppendingString:@".tombstones"]];
    }
    [inputs addObjectsFromArray:@[
        @"", @"tombstones", @".tombstones", @"hello", @"hello.tombstones",
        @"com.apple.SensorKit", @"com.apple.SensorKit.tombstones",
        @"com.apple.SensorKit.motion.accelerometer.tombstones.tombstones",
        @"com.apple.sensorkit.motion.accelerometer",
        @"COM.APPLE.SENSORKIT.MOTION.ACCELEROMETER",
        @"com.apple.SensorKit.motion.accelerometer ",
        @" com.apple.SensorKit.motion.accelerometer",
        @"Tombstones", @"TOMBSTONES",
    ]];

    SEL sel = sel_registerName("sr_sensorForDeletionRecordsFromSensor");
    for (NSString *input in inputs) {
        id result = [input performSelector:sel];
        printf("PORT\t%s\t%s\n", [input UTF8String], result ? [result UTF8String] : "(nil)");
    }
    return 0;
}