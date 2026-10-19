#import <UIKit/UIKit.h>

@interface UIPasteboard (CharonOptionsRecord)
- (void)charonRecordOptions:(NSDictionary *)options;
@end

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
    [self charonRecordOptions:options];
    [self setObjects:objects];
}

@end
