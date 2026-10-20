#import <MapKit/MapKit.h>
#import "RevenantMapKit.h"

@implementation MKLocalSearchCompletion {
    NSString *_title;
    NSString *_subtitle;
    NSArray<NSValue *> *_titleHighlightRanges;
    NSArray<NSValue *> *_subtitleHighlightRanges;
}

@synthesize title = _title;
@synthesize subtitle = _subtitle;
@synthesize titleHighlightRanges = _titleHighlightRanges;
@synthesize subtitleHighlightRanges = _subtitleHighlightRanges;

- (NSString *)description
{
    return [NSString stringWithFormat:@"<MKLocalSearchCompletion: %p %@ -- %@>", self, _title, _subtitle];
}

@end
