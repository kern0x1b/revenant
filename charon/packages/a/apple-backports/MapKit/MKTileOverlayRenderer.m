// MKTileOverlayRenderer: the tiles of an MKTileOverlay drawn where they belong. The release's map
// view hands the renderer the map rect to draw and the zoom scale, the renderer's own
// pointForMapPoint: turns the map rect into a rectangle of the view, and the tiles of the standard
// slippy pyramid that fall in it are fetched through the overlay's own loadTileAtPath: -- so an
// overlay with a custom loader keeps its custom loader -- and drawn.
#import <MapKit/MKTileOverlayRenderer.h>
#import <UIKit/UIKit.h>
#import <math.h>
#import "CharonMapKit.h"

@implementation MKTileOverlayRenderer {
    // The tiles fetched so far, keyed by the path that asked for one, so that a second draw of the
    // same region does not ask for them again and a pan over the same tiles asks once. A private
    // ivar and not a property, so the class carries no member of its own: apple/backports.lua's
    // added_members() reads any Objective-C selector the library adds as API the package carries.
    NSMutableDictionary *_charon_tiles;
}

- (instancetype)initWithOverlay:(id <MKOverlay>)overlay
{
    self = [super initWithOverlay:overlay];
    if (self) {
        _charon_tiles = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (instancetype)initWithTileOverlay:(MKTileOverlay *)overlay
{
    return [self initWithOverlay:overlay];
}

- (MKTileOverlay *)tileOverlay
{
    return (MKTileOverlay *)self.overlay;
}

// The header's own way of saying the tiles are stale: everything already fetched is dropped, so the
// next draw asks the overlay again.
- (void)reloadData
{
    [_charon_tiles removeAllObjects];
}

// The bytes of one tile through the overlay's own loader, and the image they are. The loader calls
// back on the thread that asked, which is the map view's own drawing thread here, so the answer can
// be used straight away.
- (UIImage *)charon_imageForPath:(MKTileOverlayPath)path
{
    MKTileOverlay *overlay = self.tileOverlay;
    if (!overlay) {
        return nil;
    }
    NSString *key = [NSString stringWithFormat:@"%ld/%ld/%ld/%.0f", (long)path.z, (long)path.x, (long)path.y,
                     (double)path.contentScaleFactor];
    id cached = [_charon_tiles objectForKey:key];
    if (cached) {
        // A tile that did not come is remembered as absent, so a region with no tiles on the server
        // is asked for once and not once per frame.
        return cached == [NSNull null] ? nil : (UIImage *)cached;
    }
    __block UIImage *image = nil;
    [overlay loadTileAtPath:path result:^(NSData *data, __unused NSError *error) {
        if (data.length > 0) {
            image = [UIImage imageWithData:data];
        }
    }];
    // A tile that did not come is remembered as absent, so a region with no tiles on the server is
    // asked for once and not once per frame.
    [_charon_tiles setObject:image ?: (id)[NSNull null] forKey:key];
    return image;
}

- (void)drawMapRect:(MKMapRect)mapRect zoomScale:(MKZoomScale)zoomScale inContext:(CGContextRef)context
{
    [super drawMapRect:mapRect zoomScale:zoomScale inContext:context];
    MKTileOverlay *overlay = self.tileOverlay;
    if (!overlay || !context) {
        return;
    }
    CGRect area = [self rectForMapRect:mapRect];
    if (CGRectIsNull(area) || CGRectIsEmpty(area)) {
        return;
    }
    // The pyramid level whose tiles are about the size of a point on this screen: the zoom scale
    // the map view drew at, rounded, clamped to the range the overlay says it has.
    NSInteger zoom = (NSInteger)llround((double)zoomScale);
    NSInteger lowest = overlay.minimumZ;
    NSInteger highest = overlay.maximumZ;
    if (lowest < 0) {
        lowest = 0;
    }
    if (highest < lowest) {
        highest = lowest;
    }
    if (zoom < lowest) {
        zoom = lowest;
    }
    if (zoom > highest) {
        zoom = highest;
    }
    NSInteger tiles = (NSInteger)llround(pow(2.0, (double)zoom));
    if (tiles <= 0) {
        return;
    }
    double tileMapPoints = (double)MKMapSizeWorld.width / (double)tiles;
    CGFloat contentScale = self.contentScaleFactor;
    for (NSInteger y = (NSInteger)floor(mapRect.origin.y / tileMapPoints); y <= (NSInteger)floor(MKMapRectGetMaxY(mapRect) / tileMapPoints); y++) {
        for (NSInteger x = (NSInteger)floor(mapRect.origin.x / tileMapPoints); x <= (NSInteger)floor(MKMapRectGetMaxX(mapRect) / tileMapPoints); x++) {
            if (x < 0 || y < 0 || tiles <= x || tiles <= y) {
                continue;
            }
            MKTileOverlayPath path;
            path.x = x;
            path.y = y;
            path.z = zoom;
            path.contentScaleFactor = contentScale;
            UIImage *image = [self charon_imageForPath:path];
            if (!image) {
                continue;
            }
            MKMapRect tile = MKMapRectMake(x * tileMapPoints, y * tileMapPoints, tileMapPoints, tileMapPoints);
            CGRect target = [self rectForMapRect:MKMapRectIntersection(tile, mapRect)];
            if (CGRectIsEmpty(target)) {
                continue;
            }
            CGContextSaveGState(context);
            if (overlay.isGeometryFlipped) {
                // A tile drawn the other way up -- the overlay's geometryFlipped, which says the
                // tile at x=0, y=0 is the lower left rather than the upper left -- is drawn mirrored
                // about its own top edge, so the row the server put at the bottom lands at the bottom.
                CGContextTranslateCTM(context, 0.0, CGRectGetMinY(target) + CGRectGetHeight(target));
                CGContextScaleCTM(context, 1.0, -1.0);
                CGContextDrawImage(context, CGRectMake(CGRectGetMinX(target), 0.0, CGRectGetWidth(target), CGRectGetHeight(target)), image.CGImage);
            } else {
                CGContextDrawImage(context, target, image.CGImage);
            }
            CGContextRestoreGState(context);
        }
    }
}

@end
