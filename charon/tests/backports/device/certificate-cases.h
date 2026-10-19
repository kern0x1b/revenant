#ifndef CHARON_CERTIFICATE_CASES_H
#define CHARON_CERTIFICATE_CASES_H

typedef void (^CertificateRecorder)(NSString *name, NSString *value);

void certificate_run(CertificateRecorder record);

#endif
