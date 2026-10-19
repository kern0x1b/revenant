// MKMapItemIdentifier: a place, named the way the release's own map names one.
//
// Apple added this in iOS 18 as the way to hold a place across launches without holding the
// `MKMapItem`, and the release's own `MKMapItem` has what it is built from: `-placeID` is in the armv7
// cache of 6.1.3 (measured with apple.objc.inventory), alongside `-dictionaryRepresentation` and the
// rest of the vocabulary. So an identifier here IS the release's own place identifier, and it is
// built and read through the release's own `MKMapItem` rather than composed here.
//
// The 16.4 headers do not declare this class at all, so it is declared under Apple's own name in
// CharonMapKit.h and defined here, in the object of its own measured release (18.0).
#import <MapKit/MapKit.h>
#import <objc/message.h>
#import "CharonMapKit.h"

@implementation MKMapItemIdentifier {
    NSString *_identifierString;
    NSString *_pointOfInterestID;
    NSString *_pointOfInterestCategory;
}

// An identifier for a place the release already holds, taken from the release's own `-placeID`, and
// nil where the place has none -- because the release does not put one on every map item, and
// inventing a string that the release would not recognise is worse than saying there is none.
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
