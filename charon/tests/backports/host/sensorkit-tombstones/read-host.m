// The HOST's own -[NSString sr_sensorForDeletionRecordsFromSensor], read out of the host's SensorKit.
//
// Nothing here calls into SensorKit's reader or asks for any sensor: the framework is opened, the
// category on NSString is found through the runtime, and the method is sent. That is all the port's
// method does too, which is why the two can be compared without a device.
//
// The dlopen is not decoration and the order matters. Measured: asked BEFORE the framework is opened,
// every one of the 50 inputs raises NSInvalidArgumentException "unrecognized selector sent to instance",
// because the category lives in SensorKit.framework and has not been loaded; asked after, all 58 answer.
// A harness that forgot the dlopen would report 58 failures and look like the port disagreeing with the
// host rather than like a harness that had not loaded anything.
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#include <stdio.h>

int main(void)
{
    setvbuf(stdout, NULL, _IOLBF, 0);

    CFAllocatorRef control = *(CFAllocatorRef *)dlsym(
        dlopen("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation", RTLD_LAZY),
        "kCFAllocatorDefault");
    printf("CONTROL\tkCFAllocatorDefault\t%s\n",
           control == kCFAllocatorDefault ? "matches the host's own symbol" : "DIFFERS");

    void *lib = dlopen("/System/Library/Frameworks/SensorKit.framework/SensorKit", RTLD_LAZY);
    if (!lib) { printf("SKIP\tthe host has no SensorKit\n"); return 2; }

    SEL sel = sel_registerName("sr_sensorForDeletionRecordsFromSensor");
    Class string = objc_getClass("NSString");
    if (!string || !class_getInstanceMethod(string, sel)) {
        printf("SKIP\tthe host's SensorKit declares no such method on NSString\n");
        return 2;
    }

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

    for (NSString *input in inputs) {
        id result = [input performSelector:sel];
        printf("HOST\t%s\t%s\n", [input UTF8String], result ? [result UTF8String] : "(nil)");
    }
    return 0;
}