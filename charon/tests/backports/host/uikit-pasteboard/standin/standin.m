#import <UIKit/UIKit.h>

UIPasteboardOption const UIPasteboardOptionExpirationDate = @"expirationDate";
UIPasteboardOption const UIPasteboardOptionLocalOnly = @"localOnly";
NSArray *UIPasteboardTypeListString = nil;
NSArray *UIPasteboardTypeListURL = nil;

__attribute__((constructor)) static void charon_set_lists(void);
__attribute__((constructor)) static void charon_set_lists(void)
{
    UIPasteboardTypeListString = @[ @"charon.string.type.one", @"charon.string.type.two" ];
    UIPasteboardTypeListURL = @[ @"charon.url.type.one", @"charon.url.type.two" ];
}

NSMutableArray *charon_calls = nil;

void charon_reset_records(void);
void charon_reset_records(void)
{
    charon_calls = [NSMutableArray array];
}

NSMutableArray *charon_take_calls(void);
NSMutableArray *charon_take_calls(void)
{
    NSMutableArray *calls = charon_calls ?: [NSMutableArray array];
    charon_calls = [NSMutableArray array];
    return calls;
}

void charon_plant(NSString *mode);
static NSString *charon_planted = nil;

void charon_plant(NSString *mode)
{
    charon_planted = [mode copy];
}

NSString *charon_plant_mode(void);
NSString *charon_plant_mode(void)
{
    return charon_planted ?: @"clean";
}

@implementation UIPasteboard {
    NSArray *_items;
    NSMutableDictionary *_byType;
}

- (instancetype)init
{
    if ((self = [super init]))
        _byType = [NSMutableDictionary dictionary];
    return self;
}

- (void)setItems:(NSArray *)items
{
    [charon_calls addObject:[NSString stringWithFormat:@"setItems|%lu", (unsigned long)items.count]];
    _items = [items copy];
}

NSString *charon_reported(NSString *what);
NSString *charon_reported(NSString *what)
{
    NSString *mode = charon_plant_mode();
    if ([mode isEqualToString:@"all-wrong"])
        return @"planted-wrong";
    static BOOL misreported_once = NO;
    if ([mode isEqualToString:@"one-wrong"] && [what hasPrefix:@"setValue|"] && !misreported_once) {
        misreported_once = YES;
        NSArray *parts = [what componentsSeparatedByString:@"|"];
        return [NSString stringWithFormat:@"%@|planted-wrong|%@", parts[0], parts[2]];
    }
    return what;
}

- (NSArray *)items
{
    return _items;
}

- (void)setValue:(id)value forPasteboardType:(NSString *)type
{
    [charon_calls addObject:[NSString stringWithFormat:@"setValue|%@|%@", type, value]];
    _byType[type] = value;
}

- (id)valueForPasteboardType:(NSString *)type
{
    return _byType[type];
}

- (BOOL)containsPasteboardTypes:(NSArray *)types
{
    for (NSString *type in types)
        if (_byType[type])
            return YES;
    return NO;
}

@end
