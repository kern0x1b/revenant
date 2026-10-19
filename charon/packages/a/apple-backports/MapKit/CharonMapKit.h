#ifndef CHARON_MAPKIT_H
#define CHARON_MAPKIT_H
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

#if !CHARON_HOST_PROBE
typedef NSInteger MKLocalSearchRegionPriority;
#endif

@interface MKLocalSearchCompleter (CharonDelegate)
- (void)charon_delegateDidUpdate;
- (void)charon_delegateDidFail:(nullable NSError *)error;
@end

@interface CharonMapKit : NSObject

+ (MKMapSize)charon_mapSizeAtZoomScale:(MKZoomScale)zoomScale;
+ (MKZoomScale)charon_zoomScaleForMapSize:(MKMapSize)mapSize;

+ (CLLocationDistance)charon_metersPerMapPointAtZoomScale:(MKZoomScale)zoomScale forMapRect:(MKMapRect)mapRect;

+ (CLLocationDirection)charon_bearingFromCoordinate:(CLLocationCoordinate2D)from toCoordinate:(CLLocationCoordinate2D)to;
+ (CLLocationDirection)charon_arrivalBearingFromCoordinate:(CLLocationCoordinate2D)from toCoordinate:(CLLocationCoordinate2D)to;

+ (MKMapRect)charon_mapRectForRegion:(MKCoordinateRegion)region;

@end

void charon_sayOnce(NSString *api, NSString *why);

@interface MKMultiPoint (CharonPoints)
- (void)getCoordinates:(CLLocationCoordinate2D *)coords range:(NSRange)range;
@end

@interface MKOverlayRenderer ()
@property (nonatomic, readwrite) id <MKOverlay> overlay;
@end

#if !CHARON_HOST_PROBE
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

@interface MKLocalSearchCompleter (CharonPriority)
@property (nonatomic, assign) NSInteger regionPriority;
@property (nonatomic, copy) MKAddressFilter *addressFilter;
@end
#endif

#if !CHARON_HOST_PROBE
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

#if !CHARON_HOST_PROBE
@interface MKMapItemIdentifier : NSObject
- (nullable NSString *)identifierString;
- (instancetype)initWithMapItem:(MKMapItem *)mapItem;
@end
#endif

@interface MKCompassButton (CharonCompass)
- (void)setCompassHeading:(CLLocationDirection)heading;
@end

@interface MKOverlayPathRenderer (CharonDrawing)
- (CGFloat)charon_lineWidthAtZoomScale:(MKZoomScale)zoomScale;
@end

@interface MKPolylineRenderer (CharonDrawing)
- (CGFloat)charon_lineWidthAtZoomScale:(MKZoomScale)zoomScale;
@end

@interface MKOverlayRenderer (CharonDrawing)
- (void)charon_drawInContext:(CGContextRef)context zoomScale:(MKZoomScale)zoomScale mapRect:(MKMapRect)mapRect;
- (MKZoomScale)charon_zoomScale;
@end

NS_ASSUME_NONNULL_END

#endif
