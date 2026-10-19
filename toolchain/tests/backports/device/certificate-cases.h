#ifndef REVENANT_CERTIFICATE_CASES_H
#define REVENANT_CERTIFICATE_CASES_H

typedef void (^CertificateRecorder)(NSString *name, NSString *value);

void certificate_run(CertificateRecorder record);

#endif
