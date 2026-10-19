// MKMapItemRequest: one place, asked for by the map's own feature, answered or refused honestly.
//
// The shape of the wall is measured and it is narrow. The request is made FOR A MAP FEATURE -- the
// 16.4 header's designated initialiser is -initWithMapFeatureAnnotation: and the only other way in is
// +new, which the header marks unavailable -- and a `MKMapFeatureAnnotation` is one of the map's own
// features: a thing the map itself knows about, which arrives with a map that has features. This
// release's map has none, and `MKMapFeatureAnnotation` is registered `absent` with that reason, so
// there is nothing here for a request to resolve.
//
// What is therefore real and what is not, and the split is the same everywhere in this library:
//
//   -cancel, -cancelled, -loading          real: a running request that was asked to stop
//   -featureAnnotation, -mapFeatureAnnotation  the feature the request was made for, which is nil,
//                                          and nil is the honest answer where there is no map feature
//   -getMapItemWithCompletionHandler:       answers with the header's own error, in MKErrorDomain,
//                                          saying the map has no features to resolve -- and NOT with a
//                                          made-up place
//
// A release whose map does have features -- Apple's own -- resolves this properly, and nothing here
// stands in its way: the request holds the feature it was given, reports its own state, and hands the
// resolution to whatever asked for it.
#import <MapKit/MapKit.h>
#import <objc/message.h>

// The feature the request was made for, declared because the 16.4 header's own class is registered
// absent in this library and the compiler needs to see the type.
@interface MKFeatureAnnotation : NSObject
@end

@implementation MKMapItemRequest {
    id _featureAnnotation;
    BOOL _cancelled;
    BOOL _loading;
    NSString *_identifierString;
}

@synthesize featureAnnotation = _featureAnnotation;
@synthesize cancelled = _cancelled;
@synthesize loading = _loading;

- (instancetype)initWithMapFeatureAnnotation:(MKFeatureAnnotation *)mapFeatureAnnotation
{
    self = [super init];
    if (self) {
        _featureAnnotation = mapFeatureAnnotation;
    }
    return self;
}

// The 18.0 spelling of the same feature, which the 16.4 header does not declare. The header's own
// name, under Apple's own spelling, so a program compiled against a later header links here.
- (id)mapFeatureAnnotation
{
    return _featureAnnotation;
}

// The identifier form of the same request: a place is named by the release's own
// -[MKMapItem placeID], which is in the armv7 cache of 6.1.3 (measured with apple.objc.inventory), and
// where a feature has no identifier this is nil rather than a made-up one.
- (NSString *)mapItemIdentifier
{
    // The feature's own identifier, when the feature has one, asked through the runtime because
    // MKMapFeatureAnnotation is registered absent here and the compiler has no such declaration.
    SEL identifier = NSSelectorFromString(@"identifier");
    if (_featureAnnotation && [_featureAnnotation respondsToSelector:identifier]) {
        id value = ((id (*)(id, SEL))objc_msgSend)(_featureAnnotation, identifier);
        if ([value isKindOfClass:[NSString class]]) {
            return value;
        }
    }
    return _identifierString;
}

// The request asks the map for the place the feature names. There is no map here with features, and
// the honest answer is the header's own error in MapKit's own domain, saying exactly that.
- (void)getMapItemWithCompletionHandler:(void (^)(MKMapItem *mapItem, NSError *error))completionHandler
{
    if (!completionHandler) {
        return;
    }
    if (_cancelled) {
        dispatch_async(dispatch_get_main_queue(), ^{
        // A cancelled request answers with an ERROR, which is what the host's own does and not the
        // nil/nil pair: measured on the host, a cancelled MKLocalSearch answers nil and
        // MKErrorDomain code 1, where a search that merely finds nothing answers nil and code 4. The
        // domain and the code are the host's own.
        NSError *cancelled = [NSError errorWithDomain:MKErrorDomain code:1 userInfo:
            @{NSLocalizedDescriptionKey: @"the request was cancelled"}];
        completionHandler(nil, cancelled);
        });
        return;
    }
    _loading = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        self->_loading = NO;
        completionHandler(nil, [NSError errorWithDomain:MKErrorDomain code:1 userInfo:
            @{NSLocalizedDescriptionKey:
                  @"this release's map has no features: MKMapFeatureAnnotation is not in it, so there is "
                  @"no feature for a MKMapItemRequest to resolve into a place, and no place is invented here"}]);
    });
}

- (void)cancel
{
    _cancelled = YES;
    _loading = NO;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<MKMapItemRequest: %p %@ cancelled=%d loading=%d>", self,
            _featureAnnotation ? @"a feature" : @"no feature", _cancelled, _loading];
}

@end
