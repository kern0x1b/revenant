#import <ModelIO/ModelIO.h>
#import "CharonModelIO.h"
#import <objc/runtime.h>

// MDLColorSpec is 9.0 by registry/ModelIO/surface.json and is in no held release at all:
// dyld.first_releases() answers none for _OBJC_CLASS_$_MDLColorSpec across the whole ladder, the
// 16.4 SDK forward-declares the class (MDLLight.h:30) and never declares it, and so the registry is
// the only source that places it. An object beside it holding a class a release DOES export is
// refused by modules/apple/backports.lua's band() at the 9.0 band - the release's own eight
// classes beside one it does not have - so the class gets an object of its own, which every band
// keeps whole.

// MDLColorSpec first appears at 9.0, so the class is declared here and is CALLABLE.
@implementation MDLColorSpec
@end
