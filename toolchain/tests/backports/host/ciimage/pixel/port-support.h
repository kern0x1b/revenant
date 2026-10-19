#import <Foundation/Foundation.h>
#import <CoreImage/CoreImage.h>
#import <CoreGraphics/CoreGraphics.h>

#ifdef REVENANT_PORT
@interface RevenantCIImageAccumulator : NSObject
+ (instancetype)imageAccumulatorWithExtent:(CGRect)extent format:(CIFormat)format;
+ (instancetype)imageAccumulatorWithExtent:(CGRect)extent format:(CIFormat)format colorSpace:(CGColorSpaceRef)colorSpace;
- (CIImage *)image;
- (void)setImage:(CIImage *)image;
- (void)setImage:(CIImage *)image dirtyRect:(CGRect)dirtyRect;
- (void)clear;
@property (nonatomic, readonly) CGRect extent;
@property (nonatomic, readonly) CIFormat format;
@end

@interface RevenantCIFilterShape : NSObject
+ (instancetype)shapeWithRect:(CGRect)rect;
- (instancetype)initWithRect:(CGRect)rect;
- (RevenantCIFilterShape *)intersectWith:(RevenantCIFilterShape *)other;
- (RevenantCIFilterShape *)intersectWithRect:(CGRect)rect;
- (RevenantCIFilterShape *)unionWith:(RevenantCIFilterShape *)other;
- (RevenantCIFilterShape *)unionWithRect:(CGRect)rect;
- (RevenantCIFilterShape *)insetByX:(int)dx Y:(int)dy;
- (RevenantCIFilterShape *)transformBy:(CGAffineTransform)transform interior:(BOOL)interior;
@property (nonatomic, readonly) CGRect extent;
@end

@interface RevenantGGCtxContext : CIContext
- (instancetype)initWithContext:(CIContext *)context cgContext:(CGContextRef)cgctx options:(NSDictionary *)options;
- (CGContextRef)revenant_drawingContext;
@property (nonatomic, readonly) CGColorSpaceRef workingColorSpace;
@property (nonatomic, readonly) CIFormat workingFormat;
- (void)drawImage:(CIImage *)image inRect:(CGRect)inRect fromRect:(CGRect)fromRect;
@end

#define PORT_ACCUMULATOR RevenantCIImageAccumulator
#define PORT_SHAPE RevenantCIFilterShape
#define PORT_CONTEXT RevenantGGCtxContext
#define PORT_NAME "port"
#else
#define PORT_ACCUMULATOR CIImageAccumulator
#define PORT_SHAPE CIFilterShape
#define PORT_CONTEXT CIContext
#define PORT_NAME "host"

#endif
