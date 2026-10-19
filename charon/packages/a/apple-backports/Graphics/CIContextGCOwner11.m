#import <CoreImage/CoreImage.h>
#import <CoreGraphics/CoreGraphics.h>

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"

// A CIContext the caller made over a CGContext, and the two properties that say what a context was
// made with. iOS 6's selector table has contextWithOptions:, contextWithEAGLContext: and
// contextWithEAGLContext:options: and no contextWithCGContext: in either spelling, so there is
// nothing on the release to extend and this is a subclass of the port's own.
//
// A subclass, not a category, for a measured reason: a category that answers workingColorSpace or
// workingFormat *replaces* the framework's own, and the framework's contextWithOptions: reads both
// while it is configuring itself. With the category's answers in place the working space came back
// nothing where the framework expected its own, and the renderer died formatting a string with it. A
// subclass overrides them for its own instances only, and every other method of CIContext is the
// framework's, unchanged.

// The name is behind a macro because the two-process probe builds this file under a name of its own,
// so the port's context and the framework's are never the same class in one runtime.
#define CharonCtxContext CharonGOCtxContext

@interface CharonCtxContext : CIContext
- (instancetype)initWithContext:(CIContext *)context cgContext:(CGContextRef)cgctx options:(NSDictionary *)options;
- (CGContextRef)charon_drawingContext;
@end

@implementation CharonCtxContext {
    CGContextRef _cgctx;
    NSDictionary *_options;
}

- (instancetype)initWithContext:(CIContext *)context cgContext:(CGContextRef)cgctx options:(NSDictionary *)options
{
    // This is a CIContext, made by CIContext's own designated initialiser with the options the caller
    // gave, so everything CIContext does is the release's and only the drawing surface and the two
    // properties are added. (The `context` parameter is the caller's business, not ours: it was there
    // because this used to re-initialise itself out of a context made elsewhere, which assigned a
    // CIContext to a CharonGOCtxContext and the gate caught it.)
    (void)context;
    if ((self = [super initWithOptions:options.count ? options : @{
        kCIContextWorkingColorSpace: [NSNull null]
    }])) {
        _cgctx = cgctx;
        _options = options ?: @{};
    }
    return self;
}

- (CGContextRef)charon_drawingContext
{
    return _cgctx;
}

- (CGColorSpaceRef)workingColorSpace
{
    id space = _options[kCIContextWorkingColorSpace];
    return [space isKindOfClass:[NSNull class]] || !space ? NULL : (__bridge CGColorSpaceRef)space;
}

- (CIFormat)workingFormat
{
    id format = _options[kCIContextWorkingFormat];
    return [format isKindOfClass:[NSNumber class]] ? (CIFormat)[format unsignedIntValue] : kCIFormatRGBA8;
}

// The header's drawing method, with the rectangle it draws from and the one it draws into. The
// image is rendered to a CGImage of the source rectangle and that is drawn into the caller's context.
- (void)drawImage:(CIImage *)image inRect:(CGRect)inRect fromRect:(CGRect)fromRect
{
    if (!_cgctx || !image)
        return;
    CGImageRef made = [self createCGImage:image fromRect:fromRect format:kCIFormatRGBA8 colorSpace:NULL deferred:NO];
    if (!made)
        return;
    CGContextSaveGState(_cgctx);
    CGContextDrawImage(_cgctx, inRect, made);
    CGContextRestoreGState(_cgctx);
    CGImageRelease(made);
}

@end

@implementation CIContext (CharonGCOwner)

+ (instancetype)contextWithCGContext:(CGContextRef)cgctx options:(NSDictionary *)options
{
    return [[CharonCtxContext alloc] initWithContext:nil cgContext:cgctx options:options ?: @{}];
}

@end
