#include "../revenant_impl.h"
#import <PassKit/PassKit.h>

extern NSString *const PKPassLibraryRecoveredPassesUserInfoKey;

NSString *const BACKPORT_IMPL(PKPassLibraryRecoveredPassesUserInfoKey) = @"PKPassLibraryRecoveredPassesUserInfoKey";
