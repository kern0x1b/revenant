#pragma once

#import <Foundation/Foundation.h>
#import <CoreML/CoreML.h>

#if __has_include(<CoreML/MLAllComputeDevices.h>)
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

NSArray<id<MLComputeDeviceProtocol>> *MLAllComputeDevices(void);

@interface MLModel (MLComputeDevice)
@property (class, readonly, nonatomic, copy) NSArray<id<MLComputeDeviceProtocol>> *availableComputeDevices;
@end

#endif
