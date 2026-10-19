#ifndef CHARON_SIGNPOST_CASES_H
#define CHARON_SIGNPOST_CASES_H

#import <Foundation/Foundation.h>

typedef void (^CertificateRecorder)(NSString *name, NSString *value);

void signpost_run(CertificateRecorder record);

#endif
