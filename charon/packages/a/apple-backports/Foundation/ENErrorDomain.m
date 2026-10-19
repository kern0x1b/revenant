#import <Foundation/Foundation.h>
#import <ExposureNotification/ExposureNotification.h>

// ENErrorDomain, iOS 12.5.
//
// The one constant this framework declares with `extern NSErrorDomain const` and no value in any
// header: ENCommon.h:64 gives the name and nothing else, so there is nothing there to read.
//
// Its value was measured out of a release that has it. The iOS 16.0 arm64e cache on this machine
// (~/.charon/dyld/16.0/dyld_shared_cache_arm64e) exports it from
// /System/Library/Frameworks/ExposureNotification.framework/ExposureNotification at 0x20e5acab8, and the
// string there is:
//
//     ENErrorDomain	/System/Library/Frameworks/ExposureNotification.framework/ExposureNotification	0x20e5acab8	a888db1402000800	349931688	...	0x214db88a8	ENErrorDomain	8	8
//
// read with charon's own reader, tools/corpus/cache-value.lua, over modules/apple/dyld.lua's cache
// address space. ExposureNotification arrived in iOS 12.5 and the 16.0 cache is the oldest one on this
// machine that has the framework, which is what makes it the measurement rather than a recollection.
//
// One release per object file: the constant arrived in iOS 12.5.

NSErrorDomain const ENErrorDomain = @"ENErrorDomain";