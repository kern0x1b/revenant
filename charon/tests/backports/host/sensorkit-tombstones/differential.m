#import <Foundation/Foundation.h>
#import <objc/runtime.h>

int main(void)
{
    setvbuf(stdout, NULL, _IOLBF, 0);

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
