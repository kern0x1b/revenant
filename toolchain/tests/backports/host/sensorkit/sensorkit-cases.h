#ifndef CHARON_SENSORKIT_CASES_H
#define CHARON_SENSORKIT_CASES_H

#import <Foundation/Foundation.h>

#define OS_SIGNPOST_ID_NULL ((SRAbsoluteTime)0)

typedef void (^CertificateRecorder)(NSString *name, NSString *value);

void sensorkit_run(CertificateRecorder record);

#endif
