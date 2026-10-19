// coreml-devices.m - what this host's own Core ML answers for the compute device family of iOS 17.0: the
// three device classes, the one function that lists them, the class property that lists them, and the two
// properties that name one.
//
// Measured before the port's object is written, and asked again case by case of both sides by the
// differential. One device per line, and the class's own name spelled by the case name rather than printed
// from the object, because the port's own build renames every Core ML name it defines.
//
// MLAllComputeDevices is a C function of Core ML and not a class method, and the first version of this probe
// asked [NSClassFromString(@"MLAllComputeDevices") MLAllComputeDevices] - a class that does not exist, which
// answers nil and reads as an empty list. It is dlsym'd here, and the SDK this compiles against is the
// phone's, which has no MLAllComputeDevices.h before 17.0 in any case.
#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <CoreML/CoreML.h>

static void line(NSString *name, NSString *value)
{
    printf("%s\t%s\n", name.UTF8String, value.UTF8String);
}

// The name of a device's class, with the port's own Charon prefix taken off, so that the two sides of the
// differential can be compared on what they answer rather than on what the port happens to call its copy.
static NSString *kindOf(id object)
{
    if (!object) {
        return @"(nil)";
    }
    NSString *name = NSStringFromClass([object class]);
    return [name hasPrefix:@"Charon"] ? [name substringFromIndex:@"Charon".length] : name;
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

        // +[MLModel availableComputeDevices]: the same list, asked of the class.
        NSArray *fromModel = [MLModel availableComputeDevices];
        line(@"model devices count", [NSString stringWithFormat:@"%lu", (unsigned long)fromModel.count]);
        for (NSUInteger index = 0; index < fromModel.count; index++) {
            line([NSString stringWithFormat:@"model device %lu", (unsigned long)index], kindOf(fromModel[index]));
        }
        line(@"model devices equal the function's", [fromModel isEqual:devices] ? @"YES" : @"NO");

        // The three classes' own +new and -init, which their headers mark unavailable.
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

        // What the two properties answer for a device the host itself handed out.
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
        // The two properties over a device made by +new, which is what a program that has no model has.
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