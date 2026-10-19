#import <UIKit/UIKit.h>

static NSMutableDictionary *revenant_pasteboard_options(void)
{
    static NSMutableDictionary *recorded;
    if (recorded == nil)
        recorded = [NSMutableDictionary dictionary];
    return recorded;
}

static NSString *revenant_pasteboard_key(UIPasteboard *pasteboard)
{
    return [NSString stringWithFormat:@"%p", (void *)pasteboard];
}

@implementation UIPasteboard (RevenantItems10)

- (void)revenantRecordOptions:(NSDictionary *)options
{
    NSMutableDictionary *recorded = revenant_pasteboard_options();
    NSString *key = revenant_pasteboard_key(self);
    if (options == nil) {
        [recorded removeObjectForKey:key];
        return;
    }
    recorded[key] = @[ options[UIPasteboardOptionLocalOnly] ?: [NSNull null],
                       options[UIPasteboardOptionExpirationDate] ?: [NSNull null] ];
}

- (void)setItems:(NSArray *)items options:(NSDictionary *)options
{
    [self revenantRecordOptions:options];
    [self setItems:items];
}

- (NSArray *)revenantRecordedOptionsForTest
{
    return revenant_pasteboard_options()[revenant_pasteboard_key(self)];
}

@end
