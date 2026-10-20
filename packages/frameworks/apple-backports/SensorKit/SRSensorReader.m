#import "RevenantSensorKit.h"
#import "RevenantSensorKitValue.h"
#import <CoreMedia/CoreMedia.h>
#import <mach/mach_time.h>
#import <objc/runtime.h>

NSErrorDomain SRErrorDomain = @"SRErrorDomain";

@implementation SRSensorReader
REVENANT_SENSORKIT_UNCREATABLE_NEW_AND_INIT(@"Use initWithSensor:")

- (instancetype)initWithSensor:(SRSensor)sensor
{
    if ((self = [super init]))
        [self setSensor:sensor];
    return self;
}

- (SRAuthorizationStatus)authorizationStatus
{
    return SRAuthorizationStatusDenied;
}

- (void)fetchDevices
{
    [self notifyFetchDevicesFailed];
}

+ (void)requestAuthorizationForSensors:(NSSet<SRSensor> *)sensors completion:(void (^)(NSError *error))completion
{
    if (completion)
        completion([SRSensorReader storeUnavailableError]);
}

- (void)startRecording
{
    id<SRSensorReaderDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(sensorReader:startRecordingFailedWithError:)]) {
        [delegate sensorReader:self startRecordingFailedWithError:[SRSensorReader storeUnavailableError]];
    }
}

- (void)stopRecording
{
    id<SRSensorReaderDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(sensorReader:stopRecordingFailedWithError:)]) {
        [delegate sensorReader:self stopRecordingFailedWithError:[SRSensorReader storeUnavailableError]];
    }
}

- (void)fetch:(SRFetchRequest *)request
{
    [self notifyFetchFailed:request];
}

- (void)notifyFetchDevicesFailed
{
    id<SRSensorReaderDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(sensorReader:fetchDevicesDidFailWithError:)]) {
        [delegate sensorReader:self fetchDevicesDidFailWithError:[SRSensorReader storeUnavailableError]];
    }
}

- (void)notifyFetchFailed:(SRFetchRequest *)request
{
    id<SRSensorReaderDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(sensorReader:fetchingRequest:failedWithError:)]) {
        [delegate sensorReader:self fetchingRequest:request failedWithError:[SRSensorReader storeUnavailableError]];
    }
}

- (void)setDelegate:(id<SRSensorReaderDelegate>)delegate
{
    objc_setAssociatedObject(self, @selector(delegate), delegate, OBJC_ASSOCIATION_ASSIGN);
}

- (id<SRSensorReaderDelegate>)delegate
{
    return objc_getAssociatedObject(self, @selector(delegate));
}

- (void)setSensor:(SRSensor)sensor
{
    objc_setAssociatedObject(self, @selector(sensor), sensor, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (SRSensor)sensor
{
    return objc_getAssociatedObject(self, @selector(sensor));
}

+ (NSError *)storeUnavailableError
{
    return [NSError errorWithDomain:SRErrorDomain
                               code:SRErrorDataInaccessible
                           userInfo:@{NSLocalizedDescriptionKey: @"This release collects no sensor data: there is no "
                                                                                 "SensorKit store to read a payload from."}];
}

@end
