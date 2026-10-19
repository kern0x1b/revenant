// The database half, asked once of whichever CloudKit this binary was compiled against.
//
// One file, two builds, the shape the record half already has: database-cases.h is compiled by
// database-host.m against the host's own iOS CloudKit and by database-port.m against
// packages/a/apple-backports/CloudKit with no framework linked at all. The port ships the real CK
// names - it *is* the CloudKit backport - so the two cannot be in one binary, and running the same
// cases against both is what makes the comparison a statement about behaviour.
//
// NOTHING HERE TOUCHES THE NETWORK OR ANYONE'S ACCOUNT, and the file says how it guarantees that
// rather than promising it. The gate is CKDatabaseAccountStatus below: with an iCloud account signed
// in, a case that asks a container for anything would reach Apple's servers, so the whole run refuses
// and says why. The container under test is never the default one - it is built from an identifier
// that is nobody's - so even with the gate open no case could read another account's data.
//
// What is measured, and why these and not others:
//
// Every family measured here is PURE DATA and needs no container: a process without the
// com.apple.developer.icloud-services entitlement traps the moment a CKContainer is built - CloudKit
// says so from CKContainer.m:760 - so a differential that needed one would measure nothing at all.
// The families that are pure data are the ones that can be held to a host: CKRecordZone, CKShare and
// its participants, CKUserIdentityLookupInfo, CKRecordKeyValueSetting, CKSyncEngineState.

#import <Foundation/Foundation.h>

// The surface, declared here rather than imported, so this one file compiles the same way against
// the host's framework and against the port. The declarations are the device SDK's, which is the
// release the port carries.
extern void CharonDatabaseCases(NSMutableDictionary *out);
