#import <Foundation/Foundation.h>

/* The exported string constants of iOS 17.0, 18.2 and 26.0 that the SDK this package is compiled
   against does not declare.

   The build resolves charon@iphoneos-sdk to 16.4 (every line of a gate says sdk=16.4), and a name
   that arrived after 16.4 has no extern declaration there, so a client that names one cannot
   compile against the package's own headers. The three groups are gated on the version macros the
   SDK spells: the 16.4 SDK defines __IPHONE_16_4 and no __IPHONE_17_0, so "older than 17.0" is
   "does not define __IPHONE_17_0", and the day the build SDK moves past a version this header goes
   silent for that group rather than shadowing the SDK's own declaration. Each group is declared on
   its own because the three versions are three different SDKs' worth of newness.

   No value here is the constant's own name by assumption: all fifteen values were read out of the
   host's own Foundation by dlsym, and two of them are not what their spelling suggests
   (NSHTTPCookieSetByJavaScript holds "SetInJavaScript", and the eleven calendar identifiers hold the
   lower-case calendar names). The reading and the table are in
   facts/Foundation/NSURLResourceKeyStrings.md; the object that carries each group is named in the
   registry row. */

#if !defined(__IPHONE_17_0)
FOUNDATION_EXPORT NSString * const NSFileProtectionCompleteWhenUserInactive;
#endif

#if !defined(__IPHONE_18_2)
FOUNDATION_EXPORT NSString * const NSHTTPCookieSetByJavaScript;
#endif

#if !defined(__IPHONE_26_0)
FOUNDATION_EXPORT NSString * const NSCalendarIdentifierBangla;
FOUNDATION_EXPORT NSString * const NSCalendarIdentifierDangi;
FOUNDATION_EXPORT NSString * const NSCalendarIdentifierGujarati;
FOUNDATION_EXPORT NSString * const NSCalendarIdentifierKannada;
FOUNDATION_EXPORT NSString * const NSCalendarIdentifierMalayalam;
FOUNDATION_EXPORT NSString * const NSCalendarIdentifierMarathi;
FOUNDATION_EXPORT NSString * const NSCalendarIdentifierOdia;
FOUNDATION_EXPORT NSString * const NSCalendarIdentifierTamil;
FOUNDATION_EXPORT NSString * const NSCalendarIdentifierTelugu;
FOUNDATION_EXPORT NSString * const NSCalendarIdentifierVietnamese;
FOUNDATION_EXPORT NSString * const NSCalendarIdentifierVikram;
FOUNDATION_EXPORT NSString * const NSURLUbiquitousItemIsSyncPausedKey;
FOUNDATION_EXPORT NSString * const NSURLUbiquitousItemSupportedSyncControlsKey;
#endif
