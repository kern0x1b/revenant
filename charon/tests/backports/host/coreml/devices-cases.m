/* devices-cases.m -- what the Core ML compute device family answers, recorded for both sides.
 *
 * Nine questions over the family of iOS 17.0, asked of the host's own Core ML and of the port's classes
 * under names of their own, so the two records hold the same keys:
 *
 *   - what MLAllComputeDevices() and +[MLModel availableComputeDevices] answer, how many, and which class
 *     each element is (the Charon prefix the port's own build puts on every name it defines is taken off,
 *     so a key is about the device and not about what this build calls its copy);
 *   - whether the two lists are the same list, and whether a second call of the function answers the same
 *     array object;
 *   - what +new and -init answer on each of the three classes, and whether the object conforms to
 *     MLComputeDeviceProtocol;
 *   - what the two properties answer for a device the list hands out and for one made by +new.
 *
 * The three answers that are about hardware this release has none of are the ones the run lists as meant to
 * differ, by name: the port's list holds the one compute unit iOS 6 has, its GPU device's -metalDevice is
 * nil because there is no Metal driver, and its neural engine's -totalCoreCount is 0 because there is no
 * neural engine. The last of those is what the host answers for a device made by +new on any machine, so it
 * is the same answer from both sides and is compared like any other.
 */
#import <objc/message.h>
#import <objc/runtime.h>
#import <CoreML/CoreML.h>

#import "coreml-cases.h"

/* MLAllComputeDevices is a C function of Core ML and not a class method, so it is called by its own name,
 * which is how a program reaches it. It is NOT dlsym'd: the port's build renames every Core ML name it
 * defines, so a dlsym of the plain name finds the framework's own copy and asks the host's list on both
 * sides - which is what the first version of this file did, and the comparison said so by finding all ten
 * of its allowances stale at once. */
static NSArray *charon_all_devices(void)
{
    return MLAllComputeDevices();
}

/* The class of a device with this build's own prefix removed, so that a key names the device rather than
 * the object: the port's build renames every Core ML name it defines. */
static NSString *charon_device_kind(id device)
{
    if (device == nil) {
        return @"(nil)";
    }
    NSString *name = NSStringFromClass([(NSObject *)device class]);
    return [name hasPrefix:@"Charon"] ? [name substringFromIndex:@"Charon".length] : name;
}

static NSString *charon_device_count(NSArray *devices)
{
    return [NSString stringWithFormat:@"%lu", (unsigned long)devices.count];
}

void coreml_device_cases(CoreMLRecorder record);

void coreml_device_cases(CoreMLRecorder record)
{
    NSArray *devices = charon_all_devices();
    record(@"devices/all count", charon_device_count(devices));
    for (NSUInteger index = 0; index < devices.count; index++) {
        record([NSString stringWithFormat:@"devices/all %lu", (unsigned long)index],
               charon_device_kind(devices[index]));
    }
    record(@"devices/all called again", devices == charon_all_devices() ? @"the same array" : @"another array");

    NSArray *fromModel = [MLModel availableComputeDevices];
    record(@"devices/model count", charon_device_count(fromModel));
    for (NSUInteger index = 0; index < fromModel.count; index++) {
        record([NSString stringWithFormat:@"devices/model %lu", (unsigned long)index],
               charon_device_kind(fromModel[index]));
    }
    record(@"devices/model equals the function's", [fromModel isEqual:devices] ? @"YES" : @"NO");

    /* The three classes' own +new and -init, which each header marks unavailable, and the protocol every
     * one of them conforms to. */
    for (NSString *name in @[ @"MLCPUComputeDevice", @"MLGPUComputeDevice", @"MLNeuralEngineComputeDevice" ]) {
        Class cls = NSClassFromString(name);
        id made = cls ? ((id (*)(id, SEL))objc_msgSend)(cls, @selector(new)) : nil;
        id inited = cls ? ((id (*)(id, SEL))objc_msgSend)(((id (*)(id, SEL))objc_msgSend)(cls, @selector(alloc)),
                                                           @selector(init))
                        : nil;
        record([NSString stringWithFormat:@"devices/%@ new", name], charon_device_kind(made));
        record([NSString stringWithFormat:@"devices/%@ init", name], charon_device_kind(inited));
        record([NSString stringWithFormat:@"devices/%@ conforms", name],
               [made conformsToProtocol:NSProtocolFromString(@"MLComputeDeviceProtocol")] ? @"YES" : @"NO");
        /* The two properties, over a device this process made itself, which is all a program without a
         * model has. */
        if (made && [made respondsToSelector:@selector(metalDevice)]) {
            id metal = ((id (*)(id, SEL))objc_msgSend)(made, @selector(metalDevice));
            record(@"devices/gpu new metal device", metal ? @"a device" : @"(nil)");
        }
        if (made && [made respondsToSelector:@selector(totalCoreCount)]) {
            NSInteger cores = ((NSInteger (*)(id, SEL))objc_msgSend)(made, @selector(totalCoreCount));
            record(@"devices/ane new core count", [NSString stringWithFormat:@"%ld", (long)cores]);
        }
    }

    /* And over the devices the list itself hands out, which are the ones that know their own hardware. */
    for (id device in devices) {
        NSString *kind = charon_device_kind(device);
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