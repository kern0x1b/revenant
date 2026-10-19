#import <Foundation/Foundation.h>

/* The one flag of this group the port did not already answer under the name the release gives it:
   `NSProcessInfo.iOSAppOnVision` is `@property (readonly, getter=isiOSAppOnVision)` in Apple's
   NSProcessInfo.h:248 (iOS 26.1), and on an iPhone 4S at iOS 6.1.3 the honest answer is NO -- there is
   no Vision Pro to be running on -- which is the whole answer rather than a stub.

   The three that used to be here are not, and why they left: `-iOSAppOnMac`,
   `-macCatalystApp` and `-lowPowerModeEnabled` are not the accessors Apple's header declares for
   those three properties (NSProcessInfo.h:247, :246 and :222 declare `getter=isiOSAppOnMac`,
   `getter=isMacCatalystApp` and `getter=isLowPowerModeEnabled`), and each of the three correct
   spellings was already implemented in the file that owns its release --
   `NSProcessInfo+iOSAppOnMac14.m`, `NSProcessInfo+MacCatalyst13.m` and
   `NSProcessInfo+PowerState.m`. Carrying both spellings answered an API the release does not
   document and left the documented one to another file, so this one carried two of each and the
   library exported seven selectors where the release has four. Measured on the 6.1.3 gate of
   463407400: NSProcessInfo carried -iOSAppOnMac, -isLowPowerModeEnabled, -iOSAppOnVision,
   -isMacCatalystApp, -isiOSAppOnMac, -lowPowerModeEnabled and -macCatalystApp, and the surface's
   declared getter column names the four that are API. */

@implementation NSProcessInfo (CharonPlatform)

- (BOOL)isiOSAppOnVision
{
    return NO;
}

@end