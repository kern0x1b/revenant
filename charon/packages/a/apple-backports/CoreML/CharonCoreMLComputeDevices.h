// CharonCoreMLComputeDevices.h - the Core ML compute device family, and where it comes from.
//
// The SDK this package compiles against - the phone's, iOS 16.4 - has no MLAllComputeDevices.h,
// MLCPUComputeDevice.h, MLComputeDeviceProtocol.h, MLGPUComputeDevice.h, MLNeuralEngineComputeDevice.h or
// MLModel+MLComputeDevice.h, and every name in them arrived in iOS 17.0, so they are transcribed here from
// the SDK of iOS 26.2 that declares them. Facts only, as tools/transcribe-protocols.py@52253c0650 writes its own
// headers: no header text and no comment is copied, every signature is spelled as the 26.2 header spells it,
// and the two types it only names - the compute device protocol and Metal's own device protocol - are
// declared as the declarations the signatures need.
//
// An SDK that declares the family itself is asked first and nothing is transcribed under it: a harness that
// compiles against the Mac's SDK has those six headers, and a second declaration of a class that one already
// declares is a duplicate interface the compiler refuses. The same rule CharonCoreMLProtocols.h states for a
// protocol the SDK already defines.
//
// The protocol object is emitted by MLComputeDevices17.m, because a class that conforms names a protocol
// object at run time (measured: a translation unit that declares an interface conforming to a protocol emits
// __OBJC_PROTOCOL_$_<name>, and one that merely imports the header emits nothing).

#pragma once

#import <Foundation/Foundation.h>
#import <CoreML/CoreML.h>

#if __has_include(<CoreML/MLAllComputeDevices.h>)
// The SDK this compiles against declares the family; its own declarations are the ones to use.
#import <CoreML/MLAllComputeDevices.h>
#import <CoreML/MLCPUComputeDevice.h>
#import <CoreML/MLComputeDeviceProtocol.h>
#import <CoreML/MLGPUComputeDevice.h>
#import <CoreML/MLNeuralEngineComputeDevice.h>
#import <CoreML/MLModel+MLComputeDevice.h>
#else

@protocol MTLDevice;

@protocol MLComputeDeviceProtocol <NSObject>
@end

@interface MLCPUComputeDevice : NSObject <MLComputeDeviceProtocol>
@end

@interface MLGPUComputeDevice : NSObject <MLComputeDeviceProtocol>
@property (strong, readonly, nonatomic) id<MTLDevice> metalDevice;
@end

@interface MLNeuralEngineComputeDevice : NSObject <MLComputeDeviceProtocol>
@property (readonly, assign, nonatomic) NSInteger totalCoreCount;
@end

// The compute devices this process may run a model on, as the 26.2 header declares it: a C function of
// Core ML and not a class method, so a program reaches it by its own name and links a symbol for it.
NSArray<id<MLComputeDeviceProtocol>> *MLAllComputeDevices(void);

@interface MLModel (MLComputeDevice)
@property (class, readonly, nonatomic, copy) NSArray<id<MLComputeDeviceProtocol>> *availableComputeDevices;
@end

#endif