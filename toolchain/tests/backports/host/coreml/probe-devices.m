#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <CoreML/CoreML.h>

static void line(NSString *name, NSString *value)
{
    printf("%s\t%s\n", name.UTF8String, value.UTF8String);
}

static NSString *kindOf(id object)
{
    if (!object) {
        return @"(nil)";
    }
    NSString *name = NSStringFromClass([object class]);
    return [name hasPrefix:@"Revenant"] ? [name substringFromIndex:@"Revenant".length] : name;
}

int main(void)
{
    setbuf(stdout, NULL);
    @autoreleasepool {
        void *symbol = dlsym(RTLD_DEFAULT, "MLAllComputeDevices");
        line(@"dlsym MLAllComputeDevices", symbol ? @"found" : @"not found");
        if (!symbol) {
            return 1;
        }
        NSArray *(^allDevices)(void) = [^{
            return ((NSArray *(*)(void))symbol)();
        } copy];

        NSArray *devices = allDevices();
        line(@"all devices count", [NSString stringWithFormat:@"%lu", (unsigned long)devices.count]);
        for (NSUInteger index = 0; index < devices.count; index++) {
            line([NSString stringWithFormat:@"all device %lu", (unsigned long)index], kindOf(devices[index]));
        }
        line(@"all devices called again is the same array",
             devices == allDevices() ? @"the same array" : @"another array");

        NSArray *fromModel = [MLModel availableComputeDevices];
        line(@"model devices count", [NSString stringWithFormat:@"%lu", (unsigned long)fromModel.count]);
        for (NSUInteger index = 0; index < fromModel.count; index++) {
            line([NSString stringWithFormat:@"model device %lu", (unsigned long)index], kindOf(fromModel[index]));
        }
        line(@"model devices equal the function's", [fromModel isEqual:devices] ? @"YES" : @"NO");

        for (NSString *name in @[ @"MLCPUComputeDevice", @"MLGPUComputeDevice", @"MLNeuralEngineComputeDevice" ]) {
            Class cls = NSClassFromString(name);
            id made = ((id (*)(id, SEL))objc_msgSend)(cls, @selector(new));
            id inited = ((id (*)(id, SEL))objc_msgSend)(((id (*)(id, SEL))objc_msgSend)(cls, @selector(alloc)),
                                                        @selector(init));
            line([NSString stringWithFormat:@"%@ new", name], made ? kindOf(made) : @"(nil)");
            line([NSString stringWithFormat:@"%@ init", name], inited ? kindOf(inited) : @"(nil)");
            line([NSString stringWithFormat:@"%@ conforms to the protocol", name],
                 [made conformsToProtocol:NSProtocolFromString(@"MLComputeDeviceProtocol")] ? @"YES" : @"NO");
        }

        for (id device in devices) {
            NSString *kind = kindOf(device);
            if ([kind isEqualToString:@"MLGPUComputeDevice"]) {
                id metal = ((id (*)(id, SEL))objc_msgSend)(device, @selector(metalDevice));
                line(@"gpu metal device", metal ? @"a device" : @"(nil)");
                line(@"gpu metal conforms to MTLDevice",
                     [metal conformsToProtocol:NSProtocolFromString(@"MTLDevice")] ? @"YES" : @"NO");
            } else if ([kind isEqualToString:@"MLNeuralEngineComputeDevice"]) {
                NSInteger cores = ((NSInteger (*)(id, SEL))objc_msgSend)(device, @selector(totalCoreCount));
                line(@"ane core count", [NSString stringWithFormat:@"%ld", (long)cores]);
            }
        }
        Class gpu = NSClassFromString(@"MLGPUComputeDevice");
        id madeGpu = ((id (*)(id, SEL))objc_msgSend)(gpu, @selector(new));
        line(@"gpu new metal device",
             ((id (*)(id, SEL))objc_msgSend)(madeGpu, @selector(metalDevice)) ? @"a device" : @"(nil)");
        Class ane = NSClassFromString(@"MLNeuralEngineComputeDevice");
        id madeAne = ((id (*)(id, SEL))objc_msgSend)(ane, @selector(new));
        line(@"ane new core count",
             [NSString stringWithFormat:@"%ld",
                                        (long)((NSInteger (*)(id, SEL))objc_msgSend)(madeAne, @selector(totalCoreCount))]);
    }
    return 0;
}
