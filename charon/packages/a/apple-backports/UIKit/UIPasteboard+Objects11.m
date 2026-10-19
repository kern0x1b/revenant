#import <UIKit/UIKit.h>

// The record writer of UIPasteboard+Items10.m, declared here so this file can reach it. It is a
// category method and not a C function, so neither object exports a symbol the other has to define.
@interface UIPasteboard (CharonOptionsRecord)
- (void)charonRecordOptions:(NSDictionary *)options;
@end

// The two -[UIPasteboard setObjects…] of iOS 11.0, composed over the release's own
// -setValue:forPasteboardType:.
//
// The release (6.1.3 and 4.3, measured with objc.inventory and its selector table) already ships
// UIPasteboard with -setItems:, -items, -setValue:forPasteboardType: and -valueForPasteboardType:, so
// this is a category on the system's class and not a port class.
//
// Apple writes each object under the pasteboard type its class maps to. This release has no type
// registry, so the port maps what it can measure, from the release's own two type LISTS: a string under
// the string list, an NSURL under the URL list, and anything else under the string list as its
// -description.
//
// THE FIRST ENTRY, and the reason does not depend on how many entries the list holds. The port answers
// only for the type it was given: storing under every entry of the list would write the same bytes
// under type strings the application did not ask about, and -dataForPasteboardType: would answer for
// types it never named. If a list holds one entry the first is the only choice; if it holds several,
// the rest are left as the release has them rather than filled in behind the caller's back. An
// application that wants a specific type writes it with the release's own -setValue:forPasteboardType:.
// How many entries each list holds is measured by tests/backports/device/pasteboard10.m, which prints
// the count beside the provenance check; the row states the rule and not the number, because the number
// is a property of the release and not of this code.
//
// An object the port cannot describe, or a release that names no list, is not stored at all: the release
// would have no type to store it under.
//
// The two options go through -charonRecordOptions: of UIPasteboard+Items10.m, which writes that file's
// own record and touches nothing else - the release's storer is NOT called here, because -setItems: sets
// the board's items and an empty call would empty the board. Neither option is applied: this release has
// no store that syncs between devices and no item expiry.

static void charon_pasteboard_store(UIPasteboard *board, id object, NSArray *types)
{
    NSString *type = [types firstObject];
    if (![type isKindOfClass:[NSString class]] || type.length == 0)
        return;
    id value = nil;
    if ([object isKindOfClass:[NSString class]]) {
        value = object;
    } else if ([object isKindOfClass:[NSURL class]]) {
        value = [object absoluteString];
    } else if ([object respondsToSelector:@selector(description)]) {
        id described = [object description];
        if ([described isKindOfClass:[NSString class]] && [described length] > 0)
            value = described;
    }
    if (value == nil)
        return;
    // The pasteboard is the receiver: -setValue:forPasteboardType: is its method, and sending it to
    // the object being stored would raise on the first object of every call.
    [board setValue:value forPasteboardType:type];
}

@implementation UIPasteboard (CharonObjects11)

- (void)setObjects:(NSArray *)objects
{
    for (id object in objects) {
        NSArray *types = [object isKindOfClass:[NSURL class]] ? UIPasteboardTypeListURL : UIPasteboardTypeListString;
        charon_pasteboard_store(self, object, types);
    }
}

- (void)setObjects:(NSArray *)objects localOnly:(BOOL)localOnly expirationDate:(NSDate *)expirationDate
{
    NSMutableDictionary *options = [NSMutableDictionary dictionary];
    if (localOnly)
        options[UIPasteboardOptionLocalOnly] = @(localOnly);
    if (expirationDate)
        options[UIPasteboardOptionExpirationDate] = expirationDate;
    // The record only: the release's storer is not called, so nothing on the board is disturbed.
    [self charonRecordOptions:options];
    [self setObjects:objects];
}

@end
