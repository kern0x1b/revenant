#import <Foundation/Foundation.h>
#import <HealthKit/HealthKit.h>

extern char revenant_probe_swift_type __asm__("$s9HealthKit23HKSampleQueryDescriptorVMa");

int main(int argc, char *argv[])
{
    @autoreleasepool {
        NSLog(@"class %@", NSStringFromClass([HKStateOfMind class]));
        NSLog(@"protocol %@", NSStringFromProtocol(@protocol(HKLiveWorkoutBuilderDelegate)));
        NSLog(@"constant %@", HKErrorDomain);
        NSLog(@"swift type %p", &revenant_probe_swift_type);
    }
    return 0;
}
