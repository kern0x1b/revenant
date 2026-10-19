#ifndef CHARON_METRICVALUE_CASES_H
#define CHARON_METRICVALUE_CASES_H

#import <Foundation/Foundation.h>

typedef void (^CertificateRecorder)(NSString *name, NSString *value);

void metricvalue_run(CertificateRecorder record);

#endif
