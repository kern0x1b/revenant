#import <objc/message.h>
#import <objc/runtime.h>
#import <CoreML/CoreML.h>

#import "coreml-cases.h"

static NSArray *revenant_all_devices(void)
{
    return MLAllComputeDevices();
}

static NSString *revenant_device_kind(id device)
{
    if (device == nil) {
        return @"(nil)";
    }
    NSString *name = NSStringFromClass([(NSObject *)device class]);
    return [name hasPrefix:@"Revenant"] ? [name substringFromIndex:@"Revenant".length] : name;
}

static NSString *revenant_device_count(NSArray *devices)
{
    return [NSString stringWithFormat:@"%lu", (unsigned long)devices.count];
}

void coreml_device_cases(CoreMLRecorder record);

void coreml_device_cases(CoreMLRecorder record)
{
    NSArray *devices = revenant_all_devices();
    record(@"devices/all count", revenant_device_count(devices));
    for (NSUInteger index = 0; index < devices.count; index++) {
        record([NSString stringWithFormat:@"devices/all %lu", (unsigned long)index],
               revenant_device_kind(devices[index]));
    }
    record(@"devices/all called again", devices == revenant_all_devices() ? @"the same array" : @"another array");

    NSArray *fromModel = [MLModel availableComputeDevices];
    record(@"devices/model count", revenant_device_count(fromModel));
    for (NSUInteger index = 0; index < fromModel.count; index++) {
        record([NSString stringWithFormat:@"devices/model %lu", (unsigned long)index],
               revenant_device_kind(fromModel[index]));
    }
    record(@"devices/model equals the function's", [fromModel isEqual:devices] ? @"YES" : @"NO");

    for (NSString *name in @[ @"MLCPUComputeDevice", @"MLGPUComputeDevice", @"MLNeuralEngineComputeDevice" ]) {
        Class cls = NSClassFromString(name);
        id made = cls ? ((id (*)(id, SEL))objc_msgSend)(cls, @selector(new)) : nil;
        id inited = cls ? ((id (*)(id, SEL))objc_msgSend)(((id (*)(id, SEL))objc_msgSend)(cls, @selector(alloc)),
                                                           @selector(init))
                        : nil;
        record([NSString stringWithFormat:@"devices/%@ new", name], revenant_device_kind(made));
        record([NSString stringWithFormat:@"devices/%@ init", name], revenant_device_kind(inited));
        record([NSString stringWithFormat:@"devices/%@ conforms", name],
               [made conformsToProtocol:NSProtocolFromString(@"MLComputeDeviceProtocol")] ? @"YES" : @"NO");
        if (made && [made respondsToSelector:@selector(metalDevice)]) {
            id metal = ((id (*)(id, SEL))objc_msgSend)(made, @selector(metalDevice));
            record(@"devices/gpu new metal device", metal ? @"a device" : @"(nil)");
        }
        if (made && [made respondsToSelector:@selector(totalCoreCount)]) {
            NSInteger cores = ((NSInteger (*)(id, SEL))objc_msgSend)(made, @selector(totalCoreCount));
            record(@"devices/ane new core count", [NSString stringWithFormat:@"%ld", (long)cores]);
        }
    }

    for (id device in devices) {
        NSString *kind = revenant_device_kind(device);
        if ([kind isEqualToString:@"MLGPUComputeDevice"] && [device respondsToSelector:@selector(metalDevice)]) {
            record(@"devices/gpu listed metal device",
                   ((id (*)(id, SEL))objc_msgSend)(device, @selector(metalDevice)) ? @"a device" : @"(nil)");
        }
        if ([kind isEqualToString:@"MLNeuralEngineComputeDevice"] &&
            [device respondsToSelector:@selector(totalCoreCount)]) {
            NSInteger cores = ((NSInteger (*)(id, SEL))objc_msgSend)(device, @selector(totalCoreCount));
            record(@"devices/ane listed core count", [NSString stringWithFormat:@"%ld", (long)cores]);
        }
    }
}
