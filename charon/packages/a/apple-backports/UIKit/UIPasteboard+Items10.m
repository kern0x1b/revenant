#import <UIKit/UIKit.h>

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
    recorded[key] = @[ options[UIPasteboardOptionLocalOnly] ?: [NSNull null],
                       options[UIPasteboardOptionExpirationDate] ?: [NSNull null] ];
}

- (void)setItems:(NSArray *)items options:(NSDictionary *)options
{
    [self charonRecordOptions:options];
    [self setItems:items];
}

- (NSArray *)charonRecordedOptionsForTest
{
    return charon_pasteboard_options()[charon_pasteboard_key(self)];
}

@end
