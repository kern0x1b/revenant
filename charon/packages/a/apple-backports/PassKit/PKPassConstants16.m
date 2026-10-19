// The release's own string constant of iOS 15, PKPassLibraryRecoveredPassesUserInfoKey: the key under
// which the release's own pass library reports the passes it recovered. Its value is Apple's own,
// read out of the host's PassKit.framework by tests/backports/host/passkit-constants, which compares
// it on every run against that framework and fails the moment the two disagree.
//
// Its own object, of its own release: the two PassKit constants arrived in two releases, and one
// object file carries the API of one release -- tools/release-split.lua's own rule, and the one that
// refused PKPass14.o when both were in it.
#import <PassKit/PassKit.h>

extern NSString *const PKPassLibraryRecoveredPassesUserInfoKey;

NSString *const PKPassLibraryRecoveredPassesUserInfoKey = @"PKPassLibraryRecoveredPassesUserInfoKey";
