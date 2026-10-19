#import <Foundation/Foundation.h>
#import <Accessibility/Accessibility.h>
#import <CoreGraphics/CoreGraphics.h>

@interface AXBrailleMap (CharonFactory)

+ (instancetype)charon_mapWithDimensions:(CGSize)dimensions;

@end
