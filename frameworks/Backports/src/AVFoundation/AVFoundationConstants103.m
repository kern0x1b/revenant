#include "../revenant_impl.h"
#import <AVFoundation/AVFoundation.h>

NSString *const BACKPORT_IMPL(AVContentKeyRequestProtocolVersionsKey) = @"ProtocolVersionsKey";
NSString *const BACKPORT_IMPL(AVContentKeyRequestRetryReasonReceivedObsoleteContentKey) = @"ReceivedObsoleteKeyResponse";
NSString *const BACKPORT_IMPL(AVContentKeyRequestRetryReasonReceivedResponseWithExpiredLease) = @"ReceivedKeyResponseWithExpiredLease";
NSString *const BACKPORT_IMPL(AVContentKeyRequestRetryReasonTimedOut) = @"ReceivedKeyResponseAfterSPCTimedOut";
NSString *const BACKPORT_IMPL(AVContentKeySystemFairPlayStreaming) = @"FairPlayStreaming";
