/* The Core ML strings an application reads out of the framework itself.
 *
 * These are the constants Core ML exports as symbols rather than as enum cases, so an
 * application that links against them needs the library to carry a definition of each: they are
 * not inlined at the call site the way a case of an enumeration is, and a declaration with no
 * symbol behind it is a link error rather than a value.
 *
 * Every value below was read out of a real Core ML on the host, through the framework's own
 * exported symbols, rather than written out from the name: the names are the specification's own
 * and give no hint of the value, and the error domain in particular is not the framework's name.
 * tests/backports/host/coreml/run.sh records them again on every run -- under its own `const/` keys
 * -- and fails if one of them ever differs.
 */
#import <Foundation/Foundation.h>

#import <CoreML/MLModelError.h>
#import <CoreML/MLModelMetadataKeys.h>

/* Read from the host's own Core ML: com.apple.CoreML -- not the framework's name, and not the
 * name of this file. An application that switches on an error's domain has to see the domain a
 * release that has Core ML gives, or every error it handles becomes an error it does not know. */
NSString *const MLModelErrorDomain = @"com.apple.CoreML";

/* The five metadata keys, each of which is the key of the specification's own metadata message
 * spelled as its own name: the model description's author, license, description, version, and
 * the map of whatever else its author put in. They are keys into MLModelDescription.metadata,
 * and each one's value is the string the container carries under it. */
MLModelMetadataKey const MLModelAuthorKey = @"MLModelAuthorKey";
MLModelMetadataKey const MLModelLicenseKey = @"MLModelLicenseKey";
MLModelMetadataKey const MLModelDescriptionKey = @"MLModelDescriptionKey";
MLModelMetadataKey const MLModelVersionStringKey = @"MLModelVersionStringKey";
MLModelMetadataKey const MLModelCreatorDefinedKey = @"MLModelCreatorDefinedKey";
