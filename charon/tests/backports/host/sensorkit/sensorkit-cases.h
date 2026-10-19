#ifndef CHARON_SENSORKIT_CASES_H
#define CHARON_SENSORKIT_CASES_H

#import <Foundation/Foundation.h>

// OS_SIGNPOST_ID_NULL is an os_signpost value; the one the relations above test is SensorKit's own
// reserved value for an SRAbsoluteTime, which is zero.
#define OS_SIGNPOST_ID_NULL ((SRAbsoluteTime)0)

typedef void (^CertificateRecorder)(NSString *name, NSString *value);

void sensorkit_run(CertificateRecorder record);

#endif
