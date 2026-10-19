#ifndef CHARON_CERTIFICATE_CASES_H
#define CHARON_CERTIFICATE_CASES_H

// The recorder a case file is handed, and the shape of the cases both binaries run: the host's own
// Security framework, and the port's sheet, on the same trust.
typedef void (^CertificateRecorder)(NSString *name, NSString *value);

void certificate_run(CertificateRecorder record);

#endif
