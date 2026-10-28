#import <Vision/Vision.h>
#import <objc/runtime.h>

static inline id revenant_vision_clone(id object, NSZone *zone)
{
    id copy = [[object class] allocWithZone:zone];
    for (Class cls = [object class]; cls && cls != [NSObject class]; cls = class_getSuperclass(cls)) {
        unsigned count = 0;
        Ivar *ivars = class_copyIvarList(cls, &count);
        for (unsigned index = 0; index < count; index++) {
            const char *type = ivar_getTypeEncoding(ivars[index]);
            if (type[0] == '@') {
                object_setIvar(copy, ivars[index], object_getIvar(object, ivars[index]));
            } else {
                NSUInteger size;
                NSGetSizeAndAlignment(type, &size, NULL);
                ptrdiff_t offset = ivar_getOffset(ivars[index]);
                memcpy((char *)(__bridge void *)copy + offset, (const char *)(__bridge void *)object + offset, size);
            }
        }
        free(ivars);
    }
    return copy;
}

static inline NSError *revenant_vision_error(NSInteger code, NSString *message)
{
    return [NSError errorWithDomain:VNErrorDomain code:code userInfo:@{NSLocalizedDescriptionKey: message}];
}

@interface VNDetectContoursRequest (RevenantPerform)
- (NSArray<VNContoursObservation *> *)revenant_observationsOnImage:(id)image error:(NSError **)error;
- (nullable NSNumber *)revenant_contrastPivotValue;
- (void)revenant_setContrastPivotValue:(NSNumber *)value;
@end

@interface VNRectangleObservation (RevenantTextCorners)
- (void)revenant_setCornersTopLeft:(CGPoint)topLeft topRight:(CGPoint)topRight bottomRight:(CGPoint)bottomRight bottomLeft:(CGPoint)bottomLeft;
@end

@interface VNRecognizedText (RevenantText)
+ (instancetype)revenant_textWithString:(NSString *)string confidence:(float)confidence requestRevision:(NSUInteger)requestRevision words:(NSArray<NSDictionary *> *)words;
@end

@interface VNRecognizedTextObservation (RevenantText)
- (void)revenant_setCandidates:(NSArray<VNRecognizedText *> *)candidates;
@end
