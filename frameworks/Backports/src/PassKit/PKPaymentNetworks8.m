#include "../revenant_impl.h"
#import <PassKit/PassKit.h>

PKPaymentNetwork const BACKPORT_IMPL(PKPaymentNetworkAmex) = @"Amex";
PKPaymentNetwork const BACKPORT_IMPL(PKPaymentNetworkDiscover) = @"Discover";
PKPaymentNetwork const BACKPORT_IMPL(PKPaymentNetworkMasterCard) = @"MasterCard";
PKPaymentNetwork const BACKPORT_IMPL(PKPaymentNetworkVisa) = @"Visa";
