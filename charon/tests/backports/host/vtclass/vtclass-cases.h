#ifndef CHARON_VTCLASS_CASES_H
#define CHARON_VTCLASS_CASES_H

#import <Foundation/Foundation.h>

typedef void (^CertificateRecorder)(NSString *name, NSString *value);

void vtclass_run(CertificateRecorder record);

// The port's own value round-trip, in cases-roundtrip.m: hand-written, because it calls the
// initialiser rather than describing it, and port-only, because the host cannot be given an
// object to read a value out of.
void vtclass_roundtrip(CertificateRecorder record);

#endif
