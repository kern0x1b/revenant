#ifndef REVENANT_MAPKIT_UI_H
#define REVENANT_MAPKIT_UI_H
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <MapKit/MapKit.h>
#import "RevenantMapKit.h"

NS_ASSUME_NONNULL_BEGIN

@protocol RevenantOverlayView <NSObject>
- (instancetype)initWithFrame:(CGRect)frame;
- (instancetype)initWithCoder:(NSCoder *)coder;
- (void)setFrame:(CGRect)frame;
- (void)setBounds:(CGRect)bounds;
@property (nonatomic) CGRect bounds;
- (void)setBackgroundColor:(UIColor *)color;
- (void)setOpaque:(BOOL)opaque;
- (CGFloat)alpha;
- (void)setAlpha:(CGFloat)alpha;
- (void)setUserInteractionEnabled:(BOOL)enabled;
- (void)setAutoresizingMask:(NSUInteger)mask;
- (void)removeFromSuperview;
- (void)setNeedsDisplay;
- (void)setNeedsDisplayInRect:(CGRect)rect;
@property (nonatomic, readonly) CALayer *layer;
@end

NS_ASSUME_NONNULL_END

#endif
