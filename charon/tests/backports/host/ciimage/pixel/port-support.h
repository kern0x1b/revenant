// The port's own CoreImage classes, under the names the port's build gives them. The framework's own
// classes of the same names are in the same process and are never asked: the two never touch the same
// object, and each process answers for one of them.
#import <Foundation/Foundation.h>
#import <CoreImage/CoreImage.h>
#import <CoreGraphics/CoreGraphics.h>

#ifdef CHARON_PORT
@interface CharonCIImageAccumulator : NSObject
+ (instancetype)imageAccumulatorWithExtent:(CGRect)extent format:(CIFormat)format;
+ (instancetype)imageAccumulatorWithExtent:(CGRect)extent format:(CIFormat)format colorSpace:(CGColorSpaceRef)colorSpace;
- (CIImage *)image;
- (void)setImage:(CIImage *)image;
- (void)setImage:(CIImage *)image dirtyRect:(CGRect)dirtyRect;
- (void)clear;
@property (nonatomic, readonly) CGRect extent;
@property (nonatomic, readonly) CIFormat format;
@end

@interface CharonCIFilterShape : NSObject
+ (instancetype)shapeWithRect:(CGRect)rect;
- (instancetype)initWithRect:(CGRect)rect;
- (CharonCIFilterShape *)intersectWith:(CharonCIFilterShape *)other;
- (CharonCIFilterShape *)intersectWithRect:(CGRect)rect;
- (CharonCIFilterShape *)unionWith:(CharonCIFilterShape *)other;
- (CharonCIFilterShape *)unionWithRect:(CGRect)rect;
- (CharonCIFilterShape *)insetByX:(int)dx Y:(int)dy;
- (CharonCIFilterShape *)transformBy:(CGAffineTransform)transform interior:(BOOL)interior;
@property (nonatomic, readonly) CGRect extent;
@end

@interface CharonGGCtxContext : CIContext
- (instancetype)initWithContext:(CIContext *)context cgContext:(CGContextRef)cgctx options:(NSDictionary *)options;
- (CGContextRef)charon_drawingContext;
@property (nonatomic, readonly) CGColorSpaceRef workingColorSpace;
@property (nonatomic, readonly) CIFormat workingFormat;
- (void)drawImage:(CIImage *)image inRect:(CGRect)inRect fromRect:(CGRect)fromRect;
@end

#define PORT_ACCUMULATOR CharonCIImageAccumulator
#define PORT_SHAPE CharonCIFilterShape
#define PORT_CONTEXT CharonGGCtxContext
#define PORT_NAME "port"
#else
#define PORT_ACCUMULATOR CIImageAccumulator
#define PORT_SHAPE CIFilterShape
#define PORT_CONTEXT CIContext
#define PORT_NAME "host"

// Nothing to declare for the framework's own shape: its header carries every selector, with the
// inset spelled insetByX:Y: and taking whole numbers, which is the spelling the port is held to.
#endif
