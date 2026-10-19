#ifndef CHARON_VTCLASS_CASES_H
#define CHARON_VTCLASS_CASES_H

#import <Foundation/Foundation.h>

typedef void (^CertificateRecorder)(NSString *name, NSString *value);

void vtclass_run(CertificateRecorder record);

void vtclass_roundtrip(CertificateRecorder record);

#endif
