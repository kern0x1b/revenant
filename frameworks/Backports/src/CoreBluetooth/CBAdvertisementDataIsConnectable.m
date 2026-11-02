#include "../revenant_impl.h"
#import <Foundation/Foundation.h>

extern NSString *const CBAdvertisementDataIsConnectable;

NSString *const BACKPORT_IMPL(CBAdvertisementDataIsConnectable) = @"kCBAdvDataIsConnectable";
