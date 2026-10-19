// The release's own string constant of iOS 9, PKPassLibraryRemotePaymentPassesDidChangeNotification.
// Its value is Apple's own, read out of the host's PassKit.framework by
// tests/backports/host/passkit-constants, which compares it on every run against that framework and
// fails the moment the two disagree or the framework does not export the name.
//
// The notification is a remote payment pass posting, and a remote payment pass is a Secure
// Element's, so nothing posts this on a device with no Secure Element: the name is still Apple's,
// and it is what a program compares against. Its own object, of its own release.
#import <PassKit/PassKit.h>

extern NSString *const PKPassLibraryRemotePaymentPassesDidChangeNotification;

NSString *const PKPassLibraryRemotePaymentPassesDidChangeNotification = @"PKPassLibraryRemotePaymentPassesDidChange";
