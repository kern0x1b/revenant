#import <MapKit/MapKit.h>
#import <objc/message.h>
#import "RevenantMapKit.h"

@implementation MKMapItemIdentifier {
    NSString *_identifierString;
    NSString *_pointOfInterestID;
    NSString *_pointOfInterestCategory;
}

- (instancetype)initWithMapItem:(MKMapItem *)mapItem
{
    self = [super init];
    if (self) {
        if ([mapItem respondsToSelector:NSSelectorFromString(@"placeID")]) {
            id (*placeID)(id, SEL) = (id (*)(id, SEL))objc_msgSend;
            id value = placeID(mapItem, NSSelectorFromString(@"placeID"));
            if ([value isKindOfClass:[NSString class]]) {
                _identifierString = [value copy];
            }
        }
    }
    return self;
}

- (NSString *)identifierString
{
    return _identifierString;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<MKMapItemIdentifier: %p %@>", self, _identifierString ?: @"(none)"];
}

@end
