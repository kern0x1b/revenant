#include "../revenant_impl.h"
#import <PassKit/PassKit.h>

extern NSString *const PKPassLibraryRemotePaymentPassesDidChangeNotification;

NSString *const BACKPORT_IMPL(PKPassLibraryRemotePaymentPassesDidChangeNotification) = @"PKPassLibraryRemotePaymentPassesDidChange";
