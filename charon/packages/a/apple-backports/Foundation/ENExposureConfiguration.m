#import <Foundation/Foundation.h>
#import <ExposureNotification/ExposureNotification.h>

// ENExposureConfiguration, iOS 12.5: the twenty-four weights and thresholds an application sets and
// ENManager reads when it is asked to detect exposures.
//
// Every one of them is readwrite in Apple's own header, so every one of them here stores and returns
// what the caller gave it, and `+[ENExposureConfiguration new]` answers the same object twice. There is
// no initialiser to write beyond NSObject's: the header declares none.
//
// What an application gets before it sets anything is the other half of this file's honesty. Apple's
// own object starts from the configuration Apple recommends, and no SDK header states those numbers --
// neither SDK 26.2's ENCommon.h, whose twenty-four properties carry no default, nor any other header on
// this machine. Nor is there anything on this release that could supply them: the service that reads
// this configuration is ENManager, and ENManager.m is why this release cannot detect an exposure. So
// the twenty-four answers here before a caller sets one are the zero value of its own type -- 0, nil, or
// an empty collection -- which is what a caller who sets all twenty-four will never see and what a
// caller who reads one first must be told about. Which values Apple recommends is a measurement this
// machine cannot take: it would need the framework's own -init on a release that has it, and no
// ExposureNotification.framework exists in any SDK installed here (checked:
// /Library/Developer/CommandLineTools/SDKs/MacOSX{26.5,27}.sdk/System/Library/Frameworks/ has no
// ExposureNotification.framework), while the iOS 16.0 arm64e cache holds the class and its code but not
// a way to run it. A number put here instead would be invented, and an invented weight silently changes
// every risk score the port computes.
//
// One release per object file: every property below arrived in iOS 12.5.

@implementation ENExposureConfiguration

@end