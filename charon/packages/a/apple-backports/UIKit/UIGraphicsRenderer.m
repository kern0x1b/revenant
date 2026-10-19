#import "CharonGraphicsRenderer.h"

@implementation UIGraphicsRenderer {
@private
    UIGraphicsRendererFormat *_format;
}

+ (Class)rendererContextClass
{
    return [UIGraphicsRendererContext class];
}

+ (CGContextRef)contextWithFormat:(UIGraphicsRendererFormat *)format
{
    return NULL;
}

+ (void)prepareCGContext:(CGContextRef)context withRendererContext:(UIGraphicsRendererContext *)rendererContext
{
}

- (instancetype)init
{
    return [self initWithBounds:CGRectZero];
}

- (instancetype)initWithBounds:(CGRect)bounds
{
    return [self initWithBounds:bounds format:[UIGraphicsRendererFormat defaultFormat]];
}

- (instancetype)initWithBounds:(CGRect)bounds format:(UIGraphicsRendererFormat *)format
{
    if ((self = [super init])) {
        _format = [format copy];
        [_format _setBounds:bounds];
    }
    return self;
}

- (UIGraphicsRendererFormat *)format
{
    return _format;
}

- (BOOL)allowsImageOutput
{
    return NO;
}

- (void)pushContext:(UIGraphicsRendererContext *)context
{
    if (context.__createsImages)
        UIGraphicsPushContext(context.CGContext);
}

- (void)popContext:(UIGraphicsRendererContext *)context
{
    if (context.__createsImages)
        UIGraphicsPopContext();
}

- (BOOL)runDrawingActions:(NS_NOESCAPE UIGraphicsDrawingActions)drawingActions
         completionActions:(NS_NOESCAPE UIGraphicsDrawingActions)completionActions
                     error:(NSError **)error
{
    return [self runDrawingActions:drawingActions completionActions:completionActions format:self.format error:error];
}

- (BOOL)runDrawingActions:(NS_NOESCAPE UIGraphicsDrawingActions)drawingActions
         completionActions:(NS_NOESCAPE UIGraphicsDrawingActions)completionActions
                    format:(UIGraphicsRendererFormat *)format
                     error:(NSError **)error
{
    Class contextClass = [[self class] rendererContextClass];
    if (![contextClass isSubclassOfClass:[UIGraphicsRendererContext class]]) {
        [NSException raise:NSInvalidArgumentException
                    format:@"*** Attempting to use a Class (%@) that is not a UIGraphicsRendererContext subclass as a UIGraphicsRenderer context.",
                           contextClass];
        return NO;
    }
    CGContextRef context = [[self class] contextWithFormat:format];
    if (!context) {
        if (error)
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:0
                                     userInfo:@{NSLocalizedDescriptionKey: @"Could not create CGContextRef"}];
        return NO;
    }
    UIGraphicsRendererContext *rendererContext = [[contextClass alloc] initWithCGContext:context format:format];
    rendererContext.__createsImages = [self allowsImageOutput];
    [[self class] prepareCGContext:context withRendererContext:rendererContext];
    [self pushContext:rendererContext];
    if (drawingActions)
        drawingActions(rendererContext);
    [self popContext:rendererContext];
    if (completionActions)
        completionActions(rendererContext);
    CGContextRelease(context);
    return YES;
}

@end
