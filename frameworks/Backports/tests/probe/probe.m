#import <Foundation/Foundation.h>
#import <HealthKit/HealthKit.h>

int main(int argc, char *argv[])
{
    @autoreleasepool {
        NSLog(@"class %@", NSStringFromClass([HKStateOfMind class]));
        NSLog(@"protocol %@", NSStringFromProtocol(@protocol(HKLiveWorkoutBuilderDelegate)));
        NSLog(@"constant %@", HKErrorDomain);
        if (argc > 1)
            NSLog(@"state of mind %@", [HKStateOfMind stateOfMindWithDate:[NSDate date] kind:0 valence:0.0 labels:@[] associations:@[]]);
    }
    return 0;
}
