// MKLocalSearchCompletion: one line of a completion list. The class is the SDK's own, with its
// readonly title, subtitle and two NSValue-wrapped highlight ranges; this is the object of its own
// release (9.3, measured), because the completer of 7.0 is a different object and an object carries
// the API of one release.
//
// The release's own search fills this: the title and the subtitle are the map item's own name and
// address, and the highlight ranges are the part of the title that matched what the user typed, in
// the release's own UTF-16 ranges.
#import <MapKit/MapKit.h>
#import "CharonMapKit.h"

@implementation MKLocalSearchCompletion {
    NSString *_title;
    NSString *_subtitle;
    NSArray<NSValue *> *_titleHighlightRanges;
    NSArray<NSValue *> *_subtitleHighlightRanges;
}

// The four properties are readonly in the header and readwrite here, because the completer of 7.0
// is what builds one: the SDK's header says a completion arrives already filled.
@synthesize title = _title;
@synthesize subtitle = _subtitle;
@synthesize titleHighlightRanges = _titleHighlightRanges;
@synthesize subtitleHighlightRanges = _subtitleHighlightRanges;

- (NSString *)description
{
    return [NSString stringWithFormat:@"<MKLocalSearchCompletion: %p %@ -- %@>", self, _title, _subtitle];
}

@end
