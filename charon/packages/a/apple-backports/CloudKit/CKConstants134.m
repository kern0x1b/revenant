// What iOS 13.4 added: the record type a zone's whole contents are shared under. The value is the one
// the host's own CloudKit hands out; see facts/CloudKit/Values.md. The key that tells a
// CKErrorZoneNotFound whether the user reset the encrypted data of their account arrived in iOS 16.0
// and is in CKConstants160.m.

#import <CloudKit/CloudKit.h>

NSString *const CKRecordNameZoneWideShare = @"cloudkit.zoneshare";
