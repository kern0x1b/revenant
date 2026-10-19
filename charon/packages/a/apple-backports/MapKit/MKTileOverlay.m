#import <MapKit/MapKit.h>
#import <MapKit/MKTileOverlay.h>
#import "CharonMapKit.h"

@interface MKMultiPoint (CharonCoordinates)
- (void)setCoordinates:(const CLLocationCoordinate2D *)coords count:(NSUInteger)count;
@end

@interface CharonTileCache : NSObject
+ (instancetype)charon_shared;
- (NSData *)charon_dataForKey:(NSString *)key;
- (void)charon_setData:(NSData *)data forKey:(NSString *)key;
- (void)charon_removeAll;
@end

@implementation CharonTileCache {
    NSCache *_cache;
}

+ (instancetype)charon_shared
{
    static CharonTileCache *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [[CharonTileCache alloc] init];
    });
    return shared;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _cache = [[NSCache alloc] init];
        _cache.countLimit = 512;
    }
    return self;
}

- (NSData *)charon_dataForKey:(NSString *)key
{
    return [_cache objectForKey:key];
}

- (void)charon_setData:(NSData *)data forKey:(NSString *)key
{
    if (data) {
        [_cache setObject:data forKey:key];
    }
}

- (void)charon_removeAll
{
    [_cache removeAllObjects];
}

@end

@interface MKTileOverlay ()
@property (atomic, readwrite, nullable) NSString *URLTemplate;
@end

@implementation MKTileOverlay

@synthesize URLTemplate = _URLTemplate;
@synthesize tileSize = _tileSize;
@synthesize geometryFlipped = _geometryFlipped;
@synthesize minimumZ = _minimumZ;
@synthesize maximumZ = _maximumZ;
@synthesize canReplaceMapContent = _canReplaceMapContent;

- (MKMapRect)boundingMapRect
{
    return MKMapRectWorld;
}

- (CLLocationCoordinate2D)coordinate
{
    return MKCoordinateForMapPoint(MKMapPointMake(MKMapRectGetMidX(MKMapRectWorld), MKMapRectGetMidY(MKMapRectWorld)));
}

- (instancetype)init
{
    return [self initWithURLTemplate:nil];
}

- (instancetype)initWithURLTemplate:(NSString *)URLTemplate
{
    self = [super init];
    if (self) {
        _URLTemplate = [URLTemplate copy];
        _tileSize = CGSizeMake(256.0, 256.0);
        _geometryFlipped = NO;
        _minimumZ = 0;
        _maximumZ = 22;
        _canReplaceMapContent = NO;
    }
    return self;
}

- (NSURL *)URLForTilePath:(MKTileOverlayPath)path
{
    NSString *template_ = self.URLTemplate;
    if (!template_ || template_.length == 0) {
        return nil;
    }
    CGFloat scale = path.contentScaleFactor > 0.0 ? path.contentScaleFactor : 1.0;
    NSString *filled = [template_ stringByReplacingOccurrencesOfString:@"{x}" withString:[NSString stringWithFormat:@"%ld", (long)path.x]];
    filled = [filled stringByReplacingOccurrencesOfString:@"{y}" withString:[NSString stringWithFormat:@"%ld", (long)path.y]];
    filled = [filled stringByReplacingOccurrencesOfString:@"{z}" withString:[NSString stringWithFormat:@"%ld", (long)path.z]];
    filled = [filled stringByReplacingOccurrencesOfString:@"{scale}" withString:[NSString stringWithFormat:@"%.0f", (double)scale]];
    return [NSURL URLWithString:filled];
}

- (void)loadTileAtPath:(MKTileOverlayPath)path result:(void (^)(NSData *, NSError *))result
{
    if (!result) {
        return;
    }
    NSURL *url = [self URLForTilePath:path];
    if (!url) {
        NSError *error = [NSError errorWithDomain:@"MKErrorDomain" code:1 userInfo:
                          @{NSLocalizedDescriptionKey: @"MKTileOverlay was created without a URL template, so it has no tile to load"}];
        result(nil, error);
        return;
    }
    NSString *key = [NSString stringWithFormat:@"%@|%ld|%ld|%ld|%.0f", url.absoluteString, (long)path.x, (long)path.y, (long)path.z, (double)path.contentScaleFactor];
    CharonTileCache *cache = [CharonTileCache charon_shared];
    NSData *cached = [cache charon_dataForKey:key];
    if (cached) {
        result(cached, nil);
        return;
    }
    NSURLResponse *response = nil;
    NSError *error = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest:[NSURLRequest requestWithURL:url]
                                             returningResponse:&response
                                                         error:&error];
    if (data) {
        [cache charon_setData:data forKey:key];
        result(data, nil);
    } else {
        result(nil, error);
    }
}

@end
