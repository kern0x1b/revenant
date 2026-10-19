#import <Foundation/Foundation.h>

// What a new SceneKit object answers for every property the port carries, read by key-value coding and written as
// text that does not depend on the platform. Built for macOS by host/scenekit-defaults/refresh.sh, whose answers
// become scenekit-defaults-expectations.h, and for iOS by scenekit-defaults.m against the port.
void charon_scenekit_default_cases(void (^report)(NSString *name, NSString *value));
