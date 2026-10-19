// The notification an application observes for the account it is signed in as. The value is the
// one the host's own CloudKit hands out; see facts/CloudKit/Values.md.

#import <CloudKit/CloudKit.h>

NSString *const CKAccountChangedNotification = @"CKAccountChangedNotification";
