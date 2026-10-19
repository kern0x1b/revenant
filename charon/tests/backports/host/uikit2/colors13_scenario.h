#import "uirest.h"

static BOOL ur_port_mode;

// A prefixed selector for the port's copy of a name, spelled the way prefix_selectors.py's prefixed()
// spells it, which is not simply "charonHost" in front of the name. An Objective-C family keyword keeps
// its own spelling and the prefix goes after it, so the method is still an initializer and clang's family
// rules still see one: initWithDynamicProvider: becomes initCharonHostWithDynamicProvider:, not
// charonHostInitWithDynamicProvider:. Measured on this group, linking the port's own object:
//
//   $ nm colors13/UIColorDynamic.m.o | grep DynamicProvider
//   00000000000001a8 t +[UIColor(CharonDynamicColor) charonHostColorWithDynamicProvider:]
//   0000000000000444 t -[UIColor(CharonDynamicColor) initCharonHostWithDynamicProvider:]
//
// and with that object linked, [UIColor alloc] - whose class the host names UIPlaceholderColor, and which
// IS a UIColor subclass - answers initWithDynamicProvider: and not the name this header was asking for:
// "unrecognized selector sent to instance", exit 134. Four other groups carry family keywords too
// (controlactions, controlmenus, views13), which is why the rule is spelled once and here rather than
// patched per group.
static SEL ur_sel(const char *name)
{
    if (!ur_port_mode)
        return sel_registerName(name);
    static const char *families[] = {"mutableCopy", "copy", "init", "new", "alloc"};
    char renamed[256];
    for (size_t index = 0; index < sizeof(families) / sizeof(families[0]); index++) {
        size_t length = strlen(families[index]);
        if (strncmp(name, families[index], length) != 0)
            continue;
        char tail = name[length];
        if (tail == '\0' || (tail >= 'A' && tail <= 'Z')) {
            snprintf(renamed, sizeof(renamed), "%sCharonHost%s", families[index], name + length);
            return sel_registerName(renamed);
        }
    }
    snprintf(renamed, sizeof(renamed), "charonHost%c%s", name[0] - 32, name + 1);
    return sel_registerName(renamed);
}

static UIColor *ur_dynamic(UIColor *(^provider)(UITraitCollection *))
{
    return ((UIColor * (*)(Class, SEL, id))objc_msgSend)([UIColor class], ur_sel("colorWithDynamicProvider:"), provider);
}

// The port's own spelling of -initWithDynamicProvider:, declared so that the send below is a real message
// send. An initializer consumes its receiver: [UIColor alloc] is +1 and -initWithCGColor: gives it back, which
// is why ARC emits no release for a typed `[[UIColor alloc] init...]`. Through an objc_msgSend cast the
// compiler cannot see the family, so it treats the call as an ordinary function returning an unretained object
// and releases the [UIColor alloc] result as well - one release too many. UIColor on this host is a class
// cluster whose +allocWithZone: hands back ONE shared placeholder (measured: two allocations answer the same
// pointer, and a fresh one answers retainCount 2), so the extra release destroys it and the next [UIColor
// alloc] returns freed memory:
//
//   #0 objc_retainAutoreleaseReturnValue  #1 +[UIColor allocWithZone:]  #2 charon_dynamic UIColorDynamic.m:22
//
// which is the SIGSEGV (exit 139) this group died on. Measured on both sides of the differential, with the
// port's object linked and with none: the placeholder's retainCount is 3 before the call and 2 after it, the
// system's own -[UIColor initWithDynamicProvider:] included. With the send spelled out, the group is green.
@interface UIColor (UrHostDynamicInit)
- (instancetype)initCharonHostWithDynamicProvider:(UIColor *(^)(UITraitCollection *))provider;
@end

static UIColor *ur_dynamic_init(UIColor *(^provider)(UITraitCollection *))
{
    UIColor *allocated = [UIColor alloc];
    if (ur_port_mode)
        return [allocated initCharonHostWithDynamicProvider:provider];
    return [allocated initWithDynamicProvider:provider];
}

static UIColor *ur_resolve(UIColor *color, UITraitCollection *t)
{
    return ((UIColor * (*)(id, SEL, id))objc_msgSend)(color, ur_sel("resolvedColorWithTraitCollection:"), t);
}

static UIColor *ur_named(NSString *name)
{
    return ((UIColor * (*)(Class, SEL))objc_msgSend)([UIColor class], ur_sel(name.UTF8String));
}

static NSString *rgba(UIColor *color)
{
    if (!color)
        return @"nil";
    CGFloat r, g, b, a;
    if (![color getRed:&r green:&g blue:&b alpha:&a]) {
        CGFloat w;
        [color getWhite:&w alpha:&a];
        r = g = b = w;
    }
    return [NSString stringWithFormat:@"%.4f,%.4f,%.4f,%.4f", r, g, b, a];
}

static UITraitCollection *traits(UIUserInterfaceStyle style, UIAccessibilityContrast contrast, UIUserInterfaceLevel level)
{
    return [UITraitCollection traitCollectionWithTraitsFromCollections:@[[UITraitCollection traitCollectionWithUserInterfaceStyle:style], [UITraitCollection traitCollectionWithAccessibilityContrast:contrast],
                                                                          [UITraitCollection traitCollectionWithUserInterfaceLevel:level]]];
}

static NSArray *colors_scenario(void)
{
    NSMutableArray *lines = [NSMutableArray array];
    UIColor *(^provider)(UITraitCollection *) = ^UIColor *(UITraitCollection *t) {
        if (t.userInterfaceStyle == UIUserInterfaceStyleDark)
            return t.accessibilityContrast == UIAccessibilityContrastHigh ? [UIColor colorWithRed:1 green:1 blue:0 alpha:1] : [UIColor colorWithRed:1 green:0 blue:0 alpha:1];
        return t.userInterfaceLevel == UIUserInterfaceLevelElevated ? [UIColor colorWithRed:0 green:1 blue:0 alpha:0.5] : [UIColor colorWithRed:0 green:0 blue:1 alpha:1];
    };
    UIColor *dynamic = ur_dynamic(provider);
    UIColor *other = ur_dynamic_init(provider);
    for (UIUserInterfaceStyle style = UIUserInterfaceStyleUnspecified; style <= UIUserInterfaceStyleDark; style++) {
        for (UIAccessibilityContrast contrast = UIAccessibilityContrastUnspecified; contrast <= UIAccessibilityContrastHigh; contrast++) {
            for (UIUserInterfaceLevel level = UIUserInterfaceLevelUnspecified; level <= UIUserInterfaceLevelElevated; level++) {
                UITraitCollection *t = traits(style, contrast, level);
                [lines addObject:[NSString stringWithFormat:@"resolved %ld %ld %ld %@ %@", (long)style, (long)contrast, (long)level, rgba(ur_resolve(dynamic, t)), rgba(ur_resolve(other, t))]];
            }
        }
    }
    [lines addObject:ur_line(@"as created", rgba(dynamic))];
    UIColor *red = [UIColor colorWithRed:1 green:0 blue:0 alpha:1];
    [lines addObject:ur_line(@"plain color resolves to itself", @[ur_yes(ur_resolve(red, traits(UIUserInterfaceStyleDark, UIAccessibilityContrastHigh, UIUserInterfaceLevelElevated)) == red)])];
    UIColor *inner = ur_dynamic(^UIColor *(UITraitCollection *t) { return dynamic; });
    [lines addObject:ur_line(@"a provider that returns a dynamic colour", @[rgba(ur_resolve(inner, traits(UIUserInterfaceStyleDark, UIAccessibilityContrastNormal, UIUserInterfaceLevelBase))),
                                                                         rgba(ur_resolve(inner, traits(UIUserInterfaceStyleLight, UIAccessibilityContrastNormal, UIUserInterfaceLevelBase)))])];
    UIColor *plain = ur_dynamic(^UIColor *(UITraitCollection *t) { return [UIColor whiteColor]; });
    [lines addObject:ur_line(@"a provider that returns a gray", rgba(ur_resolve(plain, traits(UIUserInterfaceStyleDark, 0, 0))))];
    __block NSUInteger seen = 0;
    UIColor *watched = ur_dynamic(^UIColor *(UITraitCollection *t) { seen++; return [UIColor blackColor]; });
    ur_resolve(watched, traits(UIUserInterfaceStyleDark, 0, 0));
    ur_resolve(watched, traits(UIUserInterfaceStyleLight, 0, 0));
    [lines addObject:ur_line(@"the provider is asked for each resolution", @(seen >= 2))];
    [[UITraitCollection traitCollectionWithUserInterfaceStyle:UIUserInterfaceStyleDark] performAsCurrentTraitCollection:^{
        UIColor *made = ur_dynamic(provider);
        [lines addObject:ur_line(@"made in a dark current collection", rgba(ur_resolve(made, traits(UIUserInterfaceStyleLight, 0, 0))))];
    }];

    NSDictionary *evidence = @{@"linkColor": ur_named(@"linkColor"), @"systemFillColor": ur_named(@"systemFillColor"), @"secondarySystemFillColor": ur_named(@"secondarySystemFillColor"), @"tertiarySystemFillColor": ur_named(@"tertiarySystemFillColor"),
                               @"quaternarySystemFillColor": ur_named(@"quaternarySystemFillColor"), @"systemGray2Color": ur_named(@"systemGray2Color"), @"systemGray3Color": ur_named(@"systemGray3Color"),
                               @"systemGray4Color": ur_named(@"systemGray4Color"), @"systemGray5Color": ur_named(@"systemGray5Color"), @"systemGray6Color": ur_named(@"systemGray6Color")};
    for (NSString *name in [evidence.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        UIColor *color = evidence[name];
        for (UIUserInterfaceStyle style = UIUserInterfaceStyleLight; style <= UIUserInterfaceStyleDark; style++) {
            for (UIAccessibilityContrast contrast = UIAccessibilityContrastNormal; contrast <= UIAccessibilityContrastHigh; contrast++)
                [lines addObject:[NSString stringWithFormat:@"%@ %ld %ld %@", name, (long)style, (long)contrast, rgba(ur_resolve(color, traits(style, contrast, UIUserInterfaceLevelBase)))]];
        }
    }
    NSMutableArray *flat = [NSMutableArray array];
    for (NSString *entry in lines)
        [flat addObject:[entry stringByReplacingOccurrencesOfString:@"\n" withString:@" "]];
    return flat;
}
