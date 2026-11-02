#include "../revenant_impl.h"
#import <Foundation/Foundation.h>

extern NSString *const MPErrorDomain;
extern NSString *const MPMediaPlaylistPropertyAuthorDisplayName;
extern NSString *const MPMediaPlaylistPropertyDescriptionText;

NSString *const BACKPORT_IMPL(MPErrorDomain) = @"MPErrorDomain";
NSString *const BACKPORT_IMPL(MPMediaPlaylistPropertyAuthorDisplayName) = @"externalVendorDisplayName";
NSString *const BACKPORT_IMPL(MPMediaPlaylistPropertyDescriptionText) = @"descriptionInfo";
