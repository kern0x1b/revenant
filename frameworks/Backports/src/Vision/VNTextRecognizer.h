#import <Foundation/Foundation.h>
#import <ImageIO/ImageIO.h>

#ifdef __cplusplus
extern "C" {
#endif

NSString *RevenantVisionTextModelRoot(void);
NSArray *RevenantVisionTextLanguages(NSString *root, NSUInteger revision, BOOL fast);
NSArray *RevenantVisionTextLines(id image, CGImagePropertyOrientation orientation, NSDictionary *options, NSError **error);

static inline NSValue *RevenantVisionRectValue(CGRect rect)
{
    return [NSValue valueWithBytes:&rect objCType:@encode(CGRect)];
}

static inline CGRect RevenantVisionRectFromValue(NSValue *value)
{
    CGRect rect;
    [value getValue:&rect];
    return rect;
}

#ifdef __cplusplus
}
#endif
