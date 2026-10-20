#import <Foundation/Foundation.h>
#import <Accessibility/Accessibility.h>
#import <CoreGraphics/CoreGraphics.h>

@interface AXBrailleMap (RevenantFactory)

+ (instancetype)revenant_mapWithDimensions:(CGSize)dimensions;

@end
