#include "../revenant_impl.h"
#import <CallKit/CallKit.h>

NSErrorDomain const BACKPORT_IMPL(CXErrorDomain) = @"com.apple.CallKit.error";
NSErrorDomain const BACKPORT_IMPL(CXErrorDomainIncomingCall) = @"com.apple.CallKit.error.incomingcall";
NSErrorDomain const BACKPORT_IMPL(CXErrorDomainRequestTransaction) = @"com.apple.CallKit.error.requesttransaction";
NSErrorDomain const BACKPORT_IMPL(CXErrorDomainCallDirectoryManager) = @"com.apple.CallKit.error.calldirectorymanager";
