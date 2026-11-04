#include "../revenant_impl.h"
#import <Foundation/Foundation.h>

#import <CoreML/MLModelError.h>
#import <CoreML/MLModelMetadataKeys.h>

NSString *const BACKPORT_IMPL(MLModelErrorDomain) = @"com.apple.CoreML";

MLModelMetadataKey const BACKPORT_IMPL(MLModelAuthorKey) = @"MLModelAuthorKey";
MLModelMetadataKey const BACKPORT_IMPL(MLModelLicenseKey) = @"MLModelLicenseKey";
MLModelMetadataKey const BACKPORT_IMPL(MLModelDescriptionKey) = @"MLModelDescriptionKey";
MLModelMetadataKey const BACKPORT_IMPL(MLModelVersionStringKey) = @"MLModelVersionStringKey";
MLModelMetadataKey const BACKPORT_IMPL(MLModelCreatorDefinedKey) = @"MLModelCreatorDefinedKey";
