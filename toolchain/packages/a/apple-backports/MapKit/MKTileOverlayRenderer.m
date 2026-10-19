#import <MapKit/MKTileOverlayRenderer.h>
#import <UIKit/UIKit.h>
#import <math.h>
#import "RevenantMapKit.h"

@implementation MKTileOverlayRenderer {
    NSMutableDictionary *_revenant_tiles;
}

- (instancetype)initWithOverlay:(id <MKOverlay>)overlay
{
    self = [super initWithOverlay:overlay];
    if (self) {
        _revenant_tiles = [[NSMutableDictionary alloc] init];
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

- (void)reloadData
{
    [_revenant_tiles removeAllObjects];
}

- (UIImage *)revenant_imageForPath:(MKTileOverlayPath)path
{
    MKTileOverlay *overlay = self.tileOverlay;
    if (!overlay) {
        return nil;
    }
    NSString *key = [NSString stringWithFormat:@"%ld/%ld/%ld/%.0f", (long)path.z, (long)path.x, (long)path.y,
                     (double)path.contentScaleFactor];
    id cached = [_revenant_tiles objectForKey:key];
    if (cached) {
        return cached == [NSNull null] ? nil : (UIImage *)cached;
    }
    __block UIImage *image = nil;
    [overlay loadTileAtPath:path result:^(NSData *data, __unused NSError *error) {
        if (data.length > 0) {
            image = [UIImage imageWithData:data];
        }
    }];
    [_revenant_tiles setObject:image ?: (id)[NSNull null] forKey:key];
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
            UIImage *image = [self revenant_imageForPath:path];
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
