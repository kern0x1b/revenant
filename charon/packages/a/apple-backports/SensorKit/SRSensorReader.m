#import "CharonSensorKit.h"
#import "CharonSensorKitValue.h"
#import <CoreMedia/CoreMedia.h>
#import <mach/mach_time.h>
#import <objc/runtime.h>

// SRSensorReader, the object an application asks about its own authorization and then asks for data.
//
// What it answers on this release, and why, is the whole of this file. Measured, not assumed:
//
//   - the release's armv7 6.1.3 cache carries no SensorKit surface at all: there is no daemon that
//     collects a reading, no usage database, and no store to read a payload out of. objc.binary_inventory
//     over the cache finds no SR* class and no SR* symbol;
//   - so a fetch cannot succeed, and the SDK's own error domain is what says so. SensorKit's headers
//     give SRErrorCode for exactly this, and -fetch: is the one that has no readings to answer with;
//   - and the authorization is a question about a database that does not exist. The header's own three
//     values are notDetermined, denied and authorized, and the honest answer is **denied**: the user is
//     not being asked, and nothing is being collected, so nothing can be authorized. Not notDetermined -
//     that would say a prompt is still to come, and no prompt is coming.
//
// The host is the same story, measured: SensorKit.framework is in the host's SDK, and under Mac Catalyst
// the SRSensorReader class is declared - and implements nothing. respondsToSelector: is 0 for both
// +authorizationStatus and +sharedReader, and sending either raises 'unrecognized selector'. So the host
// cannot answer the reader's questions either, and there is no oracle to hold a port's answers to. What
// the host *does* answer is the four time functions, and that is the differential that exists
// (tests/backports/host/sensorkit).

// The reader is the one class of this framework the port holds state for, and its state is the handle
// the application gave it: -delegate and -sensor are declared by the SDK's own header, so this extension
// does not redeclare them, it answers them. The store a reading would come from does not exist, so
// there is nothing else to keep.

// SensorKit's error domain is the string the host's SensorKit gives it, read from the host's own
// framework: `SRErrorDomain` is @"SRErrorDomain". The reader's errors are in it, so it is carried.
NSErrorDomain SRErrorDomain = @"SRErrorDomain";

@implementation SRSensorReader
// The header closes both (SRSensorReader.h:1662 and :1663, immediately after -initWithSensor: at
// :1660) and the framework's own class is what decides what that means at run time: it implements
// both, and both raise NSInternalInconsistencyException whose reason names the door that is open -
// "Use initWithSensor:", measured on the host's own SensorKit over this class and the seventeen other
// value classes of this framework (tests/backports/host/sensorkit-value). This row was absent for want
// of that body; it is one line, and it is owed.
CHARON_SENSORKIT_UNCREATABLE_NEW_AND_INIT(@"Use initWithSensor:")

- (instancetype)initWithSensor:(SRSensor)sensor
{
    if ((self = [super init]))
        [self setSensor:sensor];
    return self;
}

- (SRAuthorizationStatus)authorizationStatus
{
    // Denied, and the reasoning is the comment above: there is no store behind this, so there is
    // nothing for a user's answer to be about. A reader that answered notDetermined would promise a
    // prompt this release never shows, and one that answered authorized would claim data it does not have.
    return SRAuthorizationStatusDenied;
}

- (void)fetchDevices
{
    // The device list is the one fetch that could in principle succeed without a database: it is the
    // hardware. This release has an accelerometer and a magnetometer in some devices and neither in
    // others, and nothing here can tell which, so the delegate is told the fetch failed rather than
    // handed a list this port would have had to invent.
    [self notifyFetchDevicesFailed];
}

// The header's three ways of asking the system to collect something. Each one is answered with the
// SDK's own failure callback, because that is what the SDK says when the store cannot serve the
// request - and a caller that is told so is in a better position than one whose completion handler
// never runs.
+ (void)requestAuthorizationForSensors:(NSSet<SRSensor> *)sensors completion:(void (^)(NSError *error))completion
{
    // There is no store to be authorized for, and the block is handed the error that says so and is
    // RUN: a caller waiting for a prompt this release never shows would wait forever otherwise. The
    // code is SensorKit's own SRErrorDataInaccessible, which is "Data is not accessible at this time".
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
    // Nothing is recording, so this is a stop that did not happen, and the SDK's own answer for that is
    // the failure callback rather than the one that says recording stopped.
    id<SRSensorReaderDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(sensorReader:stopRecordingFailedWithError:)]) {
        [delegate sensorReader:self stopRecordingFailedWithError:[SRSensorReader storeUnavailableError]];
    }
}

- (void)fetch:(SRFetchRequest *)request
{
    // No store, no readings, no payload: the request cannot be answered, and the SDK's own error is
    // the answer. The request is handed back to the delegate as the one that failed, because that is
    // what the delegate is told and there is no other request to name.
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
    // SensorKit's own domain and its own code for this, read out of SRError.h: SRErrorDataInaccessible
    // is "Data is not accessible at this time", which is exactly the wall - there is no store. The
    // description says so, because an error an application may show is worth being specific about.
    return [NSError errorWithDomain:SRErrorDomain
                               code:SRErrorDataInaccessible
                           userInfo:@{NSLocalizedDescriptionKey: @"This release collects no sensor data: there is no "
                                                                                 "SensorKit store to read a payload from."}];
}

@end
