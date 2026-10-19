#import <UIKit/UIKit.h>

// -[UIPasteboard setItems:options:] of iOS 10.0, composed over the release's own -setItems:.
//
// The release (6.1.3 and 4.3, measured with objc.inventory and its selector table) already ships
// UIPasteboard with -setItems:, -items, -setValue:forPasteboardType: and -valueForPasteboardType:, so
// this is a category on the system's class and not a port class. The release's answer is what a caller
// reads back.
//
// The two options are 10.0 concepts this release has no word for: it has no pasteboard option keys, no
// store that syncs between devices and no item expiry, so it can honour neither. They are READ here -
// which is what UIPasteboardOptionLocalOnly and UIPasteboardOptionExpirationDate exist for - and
// recorded against the pasteboard, and neither is applied. The registry row's effect says exactly that.
//
// What the release does with the items is its own answer and not the port's, and it is measured on an
// emulated iOS 6.0 in facts/UIKit/UIPasteboardIOS10.md: a process with no application does not reach the
// pasteboard store, so a write is taken and is silently lost - -setString:, -setURL:, -setImage: and
// -setColor: take without complaint and nothing is there afterwards, and -setStrings: is the one that
// raises, building a dictionary from a store it could not read. Nothing there measures -setItems: itself,
// and this file does not claim what it does: the port hands the items to the release's primitive and the
// release answers.

// The record is this file's own: one entry per pasteboard, because the options are about a pasteboard and
// not about a call. -charonRecordOptions: writes it and touches nothing else, so the sibling member
// -setObjects:localOnly:expirationDate: can record through it without reaching the release's storer and
// emptying the board. -charonRecordedOptionsForTest exists so a check can read the record back rather
// than trust that it was written.
static NSMutableDictionary *charon_pasteboard_options(void)
{
    static NSMutableDictionary *recorded;
    if (recorded == nil)
        recorded = [NSMutableDictionary dictionary];
    return recorded;
}

static NSString *charon_pasteboard_key(UIPasteboard *pasteboard)
{
    return [NSString stringWithFormat:@"%p", (void *)pasteboard];
}

@implementation UIPasteboard (CharonItems10)

- (void)charonRecordOptions:(NSDictionary *)options
{
    NSMutableDictionary *recorded = charon_pasteboard_options();
    NSString *key = charon_pasteboard_key(self);
    if (options == nil) {
        [recorded removeObjectForKey:key];
        return;
    }
    // An NSNumber for localOnly, an NSDate for expirationDate, kept as the caller sent them and
    // consulted by nothing, because this release can apply neither.
    recorded[key] = @[ options[UIPasteboardOptionLocalOnly] ?: [NSNull null],
                       options[UIPasteboardOptionExpirationDate] ?: [NSNull null] ];
}

- (void)setItems:(NSArray *)items options:(NSDictionary *)options
{
    [self charonRecordOptions:options];
    // The release's own primitive does the storing, so a caller reads back what the release kept.
    [self setItems:items];
}

- (NSArray *)charonRecordedOptionsForTest
{
    return charon_pasteboard_options()[charon_pasteboard_key(self)];
}

@end
