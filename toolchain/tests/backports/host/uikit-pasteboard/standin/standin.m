#import <UIKit/UIKit.h>

UIPasteboardOption const UIPasteboardOptionExpirationDate = @"expirationDate";
UIPasteboardOption const UIPasteboardOptionLocalOnly = @"localOnly";
NSArray *UIPasteboardTypeListString = nil;
NSArray *UIPasteboardTypeListURL = nil;

__attribute__((constructor)) static void revenant_set_lists(void);
__attribute__((constructor)) static void revenant_set_lists(void)
{
    UIPasteboardTypeListString = @[ @"revenant.string.type.one", @"revenant.string.type.two" ];
    UIPasteboardTypeListURL = @[ @"revenant.url.type.one", @"revenant.url.type.two" ];
}

NSMutableArray *revenant_calls = nil;

void revenant_reset_records(void);
void revenant_reset_records(void)
{
    revenant_calls = [NSMutableArray array];
}

NSMutableArray *revenant_take_calls(void);
NSMutableArray *revenant_take_calls(void)
{
    NSMutableArray *calls = revenant_calls ?: [NSMutableArray array];
    revenant_calls = [NSMutableArray array];
    return calls;
}

void revenant_plant(NSString *mode);
static NSString *revenant_planted = nil;

void revenant_plant(NSString *mode)
{
    revenant_planted = [mode copy];
}

NSString *revenant_plant_mode(void);
NSString *revenant_plant_mode(void)
{
    return revenant_planted ?: @"clean";
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
    [revenant_calls addObject:[NSString stringWithFormat:@"setItems|%lu", (unsigned long)items.count]];
    _items = [items copy];
}

NSString *revenant_reported(NSString *what);
NSString *revenant_reported(NSString *what)
{
    NSString *mode = revenant_plant_mode();
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
    [revenant_calls addObject:[NSString stringWithFormat:@"setValue|%@|%@", type, value]];
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
