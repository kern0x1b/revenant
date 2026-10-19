// MKTileOverlay: the description of a slippy map of the caller's own -- a URL template, a tile size,
// a zoom range and whether the tiles are drawn the right way up -- and the load of one tile, which
// this port does for real over NSURLConnection, with the answers cached per path.
#import <MapKit/MapKit.h>
#import <MapKit/MKTileOverlay.h>
#import "CharonMapKit.h"

// The release's own mutating setter on MKMultiPoint, measured present in the armv7 cache of 6.1.3,
// and the two MKOverlay members it leaves to a shape to answer.
@interface MKMultiPoint (CharonCoordinates)
- (void)setCoordinates:(const CLLocationCoordinate2D *)coords count:(NSUInteger)count;
@end

// The cache of tile answers, bounded, keyed by the path that asked for one. Charon's own, so it
// carries no API: the load method is a class method's, and the class has nowhere else to put it.
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
        // A map of a few hundred tiles, which is what a screenful needs and no more: a walk across
        // a continent must not grow the process without bound.
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

// The two members the MKOverlay protocol asks a tile overlay for. A tile overlay of the caller has
// no geometry of its own -- its tiles are wherever the URL template puts them, over the whole world
// -- so it covers the world and its centre is the middle of that, which is the origin of the
// projection and not a made-up place.
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

// The URL of one tile: the template with {x}, {y}, {z} and {scale} filled in from the path, which
// is the substitution the header documents. {scale} is the renderer's content scale factor, and a
// template without it is left with the token in place, which is what a server that only has one
// tile size expects.
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

// The load of one tile, for real: the URL of the path, fetched over NSURLConnection, and the result
// block called with the bytes or with the error that stopped it. MapKit calls this on one of its
// own drawing threads, so the fetch is synchronous here and the block is called on the thread that
// asked, which is what a caller of a custom loading overlay expects. The bytes of a tile already
// asked for are answered from the cache, so a pan over the same tiles asks the server once.
- (void)loadTileAtPath:(MKTileOverlayPath)path result:(void (^)(NSData *, NSError *))result
{
    if (!result) {
        return;
    }
    NSURL *url = [self URLForTilePath:path];
    if (!url) {
        // An overlay with no template has no tile to load and no URL to build; the error says so
        // rather than answering nil bytes with no reason.
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
