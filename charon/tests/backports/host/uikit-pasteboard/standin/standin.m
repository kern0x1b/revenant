// The stand-in for the release's UIPasteboard: it records what the port asked of it, and answers the
// release's own type lists. The plants below corrupt the RECORDED answers, not the port, so a check
// that passes with a plant in place is a check that examines nothing.
#import <UIKit/UIKit.h>

UIPasteboardOption const UIPasteboardOptionExpirationDate = @"expirationDate";
UIPasteboardOption const UIPasteboardOptionLocalOnly = @"localOnly";
// The release's own lists, and this harness does NOT know their entries: the device run that reads
// them has not happened, so nothing here may claim what the release's strings are. The stand-in is
// given two entries of the harness's own, so the check can measure WHICH entry the port used - the
// first - without claiming anything about the release's. The row states the rule and not the count.
NSArray *UIPasteboardTypeListString = nil;
NSArray *UIPasteboardTypeListURL = nil;

__attribute__((constructor)) static void charon_set_lists(void);
__attribute__((constructor)) static void charon_set_lists(void)
{
    UIPasteboardTypeListString = @[ @"charon.string.type.one", @"charon.string.type.two" ];
    UIPasteboardTypeListURL = @[ @"charon.url.type.one", @"charon.url.type.two" ];
}

// every call the port makes, in order, as "selector|argument" so the probe can read them back
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
    // The stand-in is told how to lie. A check that still passes is a check that examined nothing. The
    // mode is process-local too, for the same reason the one-wrong flag is.
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

// What the stand-in REPORTS, which is what the check reads. A plant makes it misreport, so a check that
// compares only its own expectations would go green; this one compares what the stand-in says.
NSString *charon_reported(NSString *what);
NSString *charon_reported(NSString *what)
{
    NSString *mode = charon_plant_mode();
    if ([mode isEqualToString:@"all-wrong"])
        return @"planted-wrong";
    // The "already misreported once" flag is PROCESS-LOCAL: an earlier version kept it in
    // NSUserDefaults, which persists between runs, so the second run of the plant misreported nothing
    // and the harness reported a plant that had changed nothing.
    static BOOL misreported_once = NO;
    if ([mode isEqualToString:@"one-wrong"] && [what hasPrefix:@"setValue|"] && !misreported_once) {
        // ONE wrong line: the type the stand-in reports for the FIRST store, and nothing after it
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
