// What iOS 16.0 added: the key that tells a CKErrorZoneNotFound whether the user reset the encrypted
// data of their account. The value is the one the host's own CloudKit hands out; see
// facts/CloudKit/Values.md. The record type a zone's whole contents are shared under arrived in
// iOS 13.4 and is in CKConstants134.m.

#import <CloudKit/CloudKit.h>

NSString *const CKErrorUserDidResetEncryptedDataKey = @"CKUserDidResetEncryptedData";
