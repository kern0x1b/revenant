/* The two keys of the image options dictionary, in a file of their own because an object may only
 * carry the API of a single release: the rest of Core ML's exported strings arrived in iOS 11 and
 * these with the image conversion constructors beside them. The values were read out of a real Core
 * ML on the host, through the framework's own exported symbols -- each is the key of a dictionary
 * and is spelled as its own name.
 */
#import <Foundation/Foundation.h>

#import <CoreML/MLFeatureValue+MLImageConversion.h>
/* The two keys of the image options dictionary, which is what an application passes to
 * +featureValueWithCGImage:options: to say how an image that is not the size a model wants is
 * to be brought to it. They are keys of a dictionary, and the option each names is spelled as
 * its own name. */
NSString *const MLFeatureValueImageOptionCropRect = @"MLFeatureValueImageOptionCropRect";
NSString *const MLFeatureValueImageOptionCropAndScale = @"MLFeatureValueImageOptionCropAndScale";
