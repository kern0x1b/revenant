#import "CharonFoundationIdentifiers.h"

/* The calendar identifiers and the two sync-control keys of iOS 26.0, in an object of their own and
   for that release alone: a file stays in a band while any of its symbols is in range, so a
   constant of another release defined here would be defined in the band whose release already
   exports it, which is a duplicate at load. One object per release group is what keeps
   tools/release-split.lua clean, and it is why NSFileProtectionCompleteWhenUserInactive and
   NSHTTPCookieSetByJavaScript are in objects of their own.

   Every value is the one the host's own Foundation exports for the name, read by dlsym
   (tests/backports/host/foundation-constants/), and two of the shapes are worth reading rather than
   guessing: the eleven calendar identifiers hold the lower-case calendar name the release uses
   (bangla, dangi, gujarati, kannada, malayalam, marathi, odia, tamil, telugu, vietnamese, vikram),
   and the two sync keys hold their own names. The table is in
   facts/Foundation/NSURLResourceKeyStrings.md. */

NSString * const NSCalendarIdentifierBangla = @"bangla";
NSString * const NSCalendarIdentifierDangi = @"dangi";
NSString * const NSCalendarIdentifierGujarati = @"gujarati";
NSString * const NSCalendarIdentifierKannada = @"kannada";
NSString * const NSCalendarIdentifierMalayalam = @"malayalam";
NSString * const NSCalendarIdentifierMarathi = @"marathi";
NSString * const NSCalendarIdentifierOdia = @"odia";
NSString * const NSCalendarIdentifierTamil = @"tamil";
NSString * const NSCalendarIdentifierTelugu = @"telugu";
NSString * const NSCalendarIdentifierVietnamese = @"vietnamese";
NSString * const NSCalendarIdentifierVikram = @"vikram";
NSString * const NSURLUbiquitousItemIsSyncPausedKey = @"NSURLUbiquitousItemIsSyncPausedKey";
NSString * const NSURLUbiquitousItemSupportedSyncControlsKey = @"NSURLUbiquitousItemSupportedSyncControlsKey";
