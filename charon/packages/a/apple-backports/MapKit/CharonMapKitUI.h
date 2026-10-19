// The half of this port's own declarations that needs UIKit: a renderer is the release's own
// MKOverlayView at run time while the 16.4 header calls it an NSObject, so the objects that build one
// need the view's half of it, and a host probe that links no UIKit does not. The geometry half is in
// CharonMapKit.h and is free of UIKit, which is what lets tests/backports/host/mapkit compare the
// port's arithmetic against the host's own MapKit.
// Included once: the port's own declarations are reached from every object of this library and
// from the host probes, which include this header beside the SDK's own MapKit.framework.
#ifndef CHARON_MAPKIT_UI_H
#define CHARON_MAPKIT_UI_H
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <MapKit/MapKit.h>
#import "CharonMapKit.h"

NS_ASSUME_NONNULL_BEGIN

// A renderer is the release's own MKOverlayView at run time -- the 16.4 header calls it an
// NSObject, which is the header's way of hiding that -- so the objects that build one need the
// view's half of it. Declared and not implemented: the class is the release's.
@protocol CharonOverlayView <NSObject>
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

#endif /* CHARON_MAPKIT_UI_H */
