// The compute device family of iOS 17.0: MLCPUComputeDevice, MLGPUComputeDevice,
// MLNeuralEngineComputeDevice, the one function that lists the devices a process may run a model on, and the
// class property of MLModel that lists the same ones.
//
// Measured on this host's own Core ML by tests/backports/host/coreml/probe-devices.m and held case by case by
// the Core ML differential, which asks every member of the family of both sides:
//
//   * MLAllComputeDevices() answers three devices on this host - a neural engine, a GPU and a CPU - and
//     +[MLModel availableComputeDevices] answers the same three in the same order, and the two arrays are
//     equal. A second call of the function answers another array with the same contents.
//   * all three classes answer +new and -init with an object, though each header marks both unavailable
//     (MLCPUComputeDevice.h:21-22 and its two siblings), and all three answer YES to
//     conformsToProtocol:@protocol(MLComputeDeviceProtocol).
//   * a device the list hands out knows its own hardware: the neural engine's -totalCoreCount is 16 on this
//     host and the GPU's -metalDevice is a real MTLDevice. A device made by +new knows nothing: its
//     -totalCoreCount is 0 and its -metalDevice is nil. That difference is measured, and it is why the two
//     properties here answer what a device made by +new answers on the host.
//
// **What this release has, and what it therefore answers.** iOS 6 has no Metal driver and no neural engine at
// all, so the list this port answers is the one compute unit the release has, the CPU - which is the rule the
// API worker brief states for hardware a device physically lacks, and the one MLCompute's MLCDevice follows
// (facts/MLCompute/Device.md). The GPU device is still carried, because a program asks for it by class and by
// property and the class is in the port's own SDK header; its -metalDevice answers nil and the neural
// engine's -totalCoreCount answers 0, which are the host's own answers for a device made by +new on any
// machine. Those are the answers the differential lists as meant to differ, by name, with the reason beside
// them; every other member of the family is compared like any other.

#import "CharonCoreMLComputeDevices.h"

// The initialiser MLCPUComputeDevice's own header marks unavailable (MLCPUComputeDevice.h:19), reached the way
// MLCompute's own layer factories reach theirs: a private name on a category, so that the header's
// NS_UNAVAILABLE is not what the compiler reads at the call, and the body is NSObject's own -init. Named
// Charon*, so the gate weighs it against no release and the registry is never asked about it.
@interface MLCPUComputeDevice (CharonFactory)
- (instancetype)charon_init;
@end

@implementation MLCPUComputeDevice (CharonFactory)

- (instancetype)charon_init
{
    return [super init];
}

@end

// The one compute device of this release, made once: MLAllComputeDevices() and
// +[MLModel availableComputeDevices] answer the same list on the host (measured, probe-devices.m), and two
// lists over two devices of their own would answer NO to -isEqual: against one another for want of a shared
// object. A program that asks twice gets the same device both times, which is what one process has.
static MLCPUComputeDevice *CharonMLComputeCPUDevice(void)
{
    static MLCPUComputeDevice *device = nil;
    if (!device) {
        device = [[MLCPUComputeDevice alloc] charon_init];
    }
    return device;
}

@implementation MLCPUComputeDevice
@end

@implementation MLGPUComputeDevice

// The Metal device of a GPU compute device: the one the process created this object over. Nil here, because
// this release has no Metal driver at all - and nil is what the host answers for a GPU compute device made by
// +new on any machine (measured, probe-devices.m), so this is the framework's own answer for a device that
// was not made over a device.
- (id<MTLDevice>)metalDevice
{
    return nil;
}

@end

@implementation MLNeuralEngineComputeDevice

// The cores of the neural engine: zero here, because this release has no neural engine - no driver, no
// engine, nothing to count. Zero is also what the host answers for a device made by +new on any machine
// (measured, probe-devices.m).
- (NSInteger)totalCoreCount
{
    return 0;
}

@end

// The compute devices this process may run a model on, as the 26.2 header declares it: a C function of Core
// ML, so a program reaches it by its own name and links a symbol for it. The port's own object list, which
// is the one compute unit this release has.
NSArray<id<MLComputeDeviceProtocol>> *MLAllComputeDevices(void)
{
    return @[CharonMLComputeCPUDevice()];
}

@implementation MLModel (MLComputeDevice)

// The compute devices this process may run a model on: the same list, and the same objects in it.
+ (NSArray<id<MLComputeDeviceProtocol>> *)availableComputeDevices
{
    return MLAllComputeDevices();
}

@end