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

#if !REVENANT_HOST_PROBE
typedef NSInteger MKLocalSearchRegionPriority;
#endif

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
typedef NS_OPTIONS(NSUInteger, MKAddressFilterOption) {
    MKAddressFilterOptionCountry          = 1 << 0,
    MKAddressFilterOptionPostalCode       = 1 << 1,
    MKAddressFilterOptionLocality         = 1 << 2,
    MKAddressFilterOptionSubLocality      = 1 << 3,
    MKAddressFilterOptionAdministrativeArea = 1 << 4,
    MKAddressFilterOptionSubAdministrativeArea = 1 << 5,
};

@interface MKAddressFilter : NSObject
+ (instancetype)filterIncludingAll;
+ (instancetype)filterExcludingAll;
- (instancetype)initIncludingOptions:(MKAddressFilterOption)options;
- (instancetype)initExcludingOptions:(MKAddressFilterOption)options;
- (BOOL)includesOptions:(MKAddressFilterOption)options;
- (BOOL)excludesOptions:(MKAddressFilterOption)options;
@end

@interface MKLocalSearchCompleter (RevenantPriority)
@property (nonatomic, assign) NSInteger regionPriority;
@property (nonatomic, copy) MKAddressFilter *addressFilter;
@end
#endif

#if !REVENANT_HOST_PROBE
@interface MKAddressRepresentations : NSObject
- (instancetype)initWithFullAddress:(NSString *)fullAddress;
@end

@interface MKAddress : NSObject
- (instancetype)initWithFullAddress:(NSString *)fullAddress;
@property (nonatomic, readonly, copy) NSString *fullAddress;
@property (nonatomic, readonly, copy) NSString *shortAddress;
- (nullable MKAddressRepresentations *)addressRepresentations;
@end
#endif

#if !REVENANT_HOST_PROBE
@interface MKMapItemIdentifier : NSObject
- (nullable NSString *)identifierString;
- (instancetype)initWithMapItem:(MKMapItem *)mapItem;
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
