#ifndef REVENANT_VIDEOTOOLBOX_CASES_H
#define REVENANT_VIDEOTOOLBOX_CASES_H

#import <Foundation/Foundation.h>

typedef void (^CertificateRecorder)(NSString *name, NSString *value);

void videotoolbox_run(CertificateRecorder record);

#endif
