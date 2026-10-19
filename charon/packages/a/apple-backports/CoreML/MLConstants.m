#import <Foundation/Foundation.h>

#import <CoreML/MLModelError.h>
#import <CoreML/MLModelMetadataKeys.h>

NSString *const MLModelErrorDomain = @"com.apple.CoreML";

MLModelMetadataKey const MLModelAuthorKey = @"MLModelAuthorKey";
MLModelMetadataKey const MLModelLicenseKey = @"MLModelLicenseKey";
MLModelMetadataKey const MLModelDescriptionKey = @"MLModelDescriptionKey";
MLModelMetadataKey const MLModelVersionStringKey = @"MLModelVersionStringKey";
MLModelMetadataKey const MLModelCreatorDefinedKey = @"MLModelCreatorDefinedKey";
