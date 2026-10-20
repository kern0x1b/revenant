#ifndef REVENANT_MAPKIT_H
#define REVENANT_MAPKIT_H
#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <MapKit/MKGeometry.h>
#import <MapKit/MKOverlayRenderer.h>
#import <MapKit/MKOverlayPathRenderer.h>
#import <MapKit/MKMultiPoint.h>
#import <MapKit/MapKit.h>

NS_ASSUME_NONNULL_BEGIN

@class MKLocalSearchCompleter;
@class MKLocalSearchCompletion;


@interface MKLocalSearchCompleter (RevenantDelegate)
- (void)revenant_delegateDidUpdate;
- (void)revenant_delegateDidFail:(nullable NSError *)error;
@end

@interface RevenantMapKit : NSObject

+ (MKMapSize)revenant_mapSizeAtZoomScale:(MKZoomScale)zoomScale;
+ (MKZoomScale)revenant_zoomScaleForMapSize:(MKMapSize)mapSize;

+ (CLLocationDistance)revenant_metersPerMapPointAtZoomScale:(MKZoomScale)zoomScale forMapRect:(MKMapRect)mapRect;

+ (CLLocationDirection)revenant_bearingFromCoordinate:(CLLocationCoordinate2D)from toCoordinate:(CLLocationCoordinate2D)to;
+ (CLLocationDirection)revenant_arrivalBearingFromCoordinate:(CLLocationCoordinate2D)from toCoordinate:(CLLocationCoordinate2D)to;

+ (MKMapRect)revenant_mapRectForRegion:(MKCoordinateRegion)region;

@end

void revenant_sayOnce(NSString *api, NSString *why);

@interface MKMultiPoint (RevenantPoints)
- (void)getCoordinates:(CLLocationCoordinate2D *)coords range:(NSRange)range;
@end

@interface MKOverlayRenderer ()
@property (nonatomic, readwrite) id <MKOverlay> overlay;
@end

#if !REVENANT_HOST_PROBE


@interface MKLocalSearchCompleter (RevenantPriority)
@property (nonatomic, assign) NSInteger regionPriority;
@property (nonatomic, copy) MKAddressFilter *addressFilter;
@end
#endif



@interface MKCompassButton (RevenantCompass)
- (void)setCompassHeading:(CLLocationDirection)heading;
@end

@interface MKOverlayPathRenderer (RevenantDrawing)
- (CGFloat)revenant_lineWidthAtZoomScale:(MKZoomScale)zoomScale;
@end

@interface MKPolylineRenderer (RevenantDrawing)
- (CGFloat)revenant_lineWidthAtZoomScale:(MKZoomScale)zoomScale;
@end

@interface MKOverlayRenderer (RevenantDrawing)
- (void)revenant_drawInContext:(CGContextRef)context zoomScale:(MKZoomScale)zoomScale mapRect:(MKMapRect)mapRect;
- (MKZoomScale)revenant_zoomScale;
@end

NS_ASSUME_NONNULL_END

#endif
