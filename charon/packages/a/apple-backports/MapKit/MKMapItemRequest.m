#import <MapKit/MapKit.h>
#import <objc/message.h>

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

- (id)mapFeatureAnnotation
{
    return _featureAnnotation;
}

- (NSString *)mapItemIdentifier
{
    SEL identifier = NSSelectorFromString(@"identifier");
    if (_featureAnnotation && [_featureAnnotation respondsToSelector:identifier]) {
        id value = ((id (*)(id, SEL))objc_msgSend)(_featureAnnotation, identifier);
        if ([value isKindOfClass:[NSString class]]) {
            return value;
        }
    }
    return _identifierString;
}

- (void)getMapItemWithCompletionHandler:(void (^)(MKMapItem *mapItem, NSError *error))completionHandler
{
    if (!completionHandler) {
        return;
    }
    if (_cancelled) {
        dispatch_async(dispatch_get_main_queue(), ^{
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
