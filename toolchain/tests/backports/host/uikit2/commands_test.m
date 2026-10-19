#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#include <dlfcn.h>
#include <dlfcn.h>
#import "check.h"

#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
#pragma clang diagnostic ignored "-Wnonnull"
#pragma clang diagnostic ignored "-Wincompatible-pointer-types"
#pragma clang diagnostic ignored "-Wundeclared-selector"

@interface CharonRecorder : NSCoder
@property (nonatomic, strong) NSMutableArray *rows;
@end

@implementation CharonRecorder

- (instancetype)init
{
    if ((self = [super init]))
        self.rows = [NSMutableArray array];
    return self;
}

- (BOOL)allowsKeyedCoding
{
    return YES;
}

- (void)encodeObject:(id)object forKey:(NSString *)key
{
    [self.rows addObject:[NSString stringWithFormat:@"object %@ %@", key, object]];
}

- (void)encodeInteger:(NSInteger)value forKey:(NSString *)key
{
    [self.rows addObject:[NSString stringWithFormat:@"integer %@ %ld", key, (long)value]];
}

- (void)encodeInt:(int)value forKey:(NSString *)key
{
    [self.rows addObject:[NSString stringWithFormat:@"int %@ %d", key, value]];
}

- (void)encodeInt32:(int32_t)value forKey:(NSString *)key
{
    [self.rows addObject:[NSString stringWithFormat:@"int32 %@ %d", key, value]];
}

- (void)encodeInt64:(int64_t)value forKey:(NSString *)key
{
    [self.rows addObject:[NSString stringWithFormat:@"int64 %@ %lld", key, value]];
}

- (void)encodeBool:(BOOL)value forKey:(NSString *)key
{
    [self.rows addObject:[NSString stringWithFormat:@"bool %@ %d", key, value]];
}

@end

static NSString *norm(id object)
{
    NSString *text = [NSString stringWithFormat:@"%@", object];
    text = [text stringByReplacingOccurrencesOfString:@"CharonHost" withString:@""];
    NSRegularExpression *pointer = [NSRegularExpression regularExpressionWithPattern:@"0x[0-9a-f]+" options:0 error:nil];
    return [pointer stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:@"PTR"];
}

static NSString *raised(id (^block)(void))
{
    @try {
        return [NSString stringWithFormat:@"ok %@", norm(block())];
    } @catch (NSException *exception) {
        NSString *reason = norm(exception.reason);
        NSRange range = [reason rangeOfString:@"-[" options:0];
        if (range.location != NSNotFound && [exception.name isEqualToString:NSInvalidArgumentException])
            reason = @"unrecognized selector";
        return [NSString stringWithFormat:@"raised %@ %@", exception.name, reason];
    }
}

static NSString *yes(BOOL value)
{
    return value ? @"YES" : @"NO";
}

static NSString *line(NSString *label, id value)
{
    return [NSString stringWithFormat:@"%@ %@", label, norm(value)];
}

static void agree(NSString *name, NSArray *ours, NSArray *system)
{
    NSMutableString *detail = [NSMutableString string];
    for (NSUInteger index = 0; index < MAX(ours.count, system.count); index++) {
        NSString *a = index < ours.count ? ours[index] : @"<none>", *b = index < system.count ? system[index] : @"<none>";
        if (![a isEqual:b])
            [detail appendFormat:@"\n    port   %@\n    system %@", a, b];
    }
    charon_check(detail.length == 0, name.UTF8String, detail);
}

static NSArray *archive_rows(id object)
{
    CharonRecorder *recorder = [[CharonRecorder alloc] init];
    [object encodeWithCoder:recorder];
    NSMutableArray *rows = [NSMutableArray array];
    for (NSString *row in recorder.rows) {
        if ([row hasPrefix:@"object accessibilityIdentifier"] || [row hasPrefix:@"object internalIdentifier"] || [row hasPrefix:@"object eventDeferringEnvironment"] || [row hasPrefix:@"bool "] || [row hasPrefix:@"int32 enumerationPriority"])
            continue;
        [rows addObject:[[row stringByReplacingOccurrencesOfString:@"CharonHost" withString:@""] copy]];
    }
    [rows sortUsingSelector:@selector(compare:)];
    return rows;
}

static NSArray *command_lines(Class command, Class alternate)
{
    NSMutableArray *lines = [NSMutableArray array];
    UIKeyModifierFlags shift = UIKeyModifierShift, cmd = UIKeyModifierCommand;
    UICommandAlternate *a = [alternate alternateWithTitle:@"alt" action:@selector(foo:) modifierFlags:shift];
    UICommandAlternate *b = [alternate alternateWithTitle:@"other" action:@selector(bar:) modifierFlags:shift];
    UICommandAlternate *c = [alternate alternateWithTitle:@"alt" action:@selector(foo:) modifierFlags:cmd];
    [lines addObject:line(@"alternate fields", @[[a title], NSStringFromSelector([a action]), @([a modifierFlags]), [b title], @([c modifierFlags])])];
    [lines addObject:line(@"alternate equality", @[yes([a isEqual:b]), yes([a isEqual:c]), yes([a isEqual:a]), yes([a isEqual:@1]), yes([a isEqual:nil]), yes([a hash] == [b hash]), yes([a hash] == [c hash])])];
    [lines addObject:line(@"alternate copy", @[yes([a copy] == a), yes([[a copy] isEqual:a])])];
    [lines addObject:line(@"alternate description", a)];
    [lines addObject:line(@"alternate archive", archive_rows(a))];
    [lines addObject:line(@"alternate with nothing", @[raised(^id { return [alternate alternateWithTitle:nil action:NULL modifierFlags:0]; })])];

    UICommand *x = [command commandWithTitle:@"T" image:nil action:@selector(foo:) propertyList:@{@"a": @1}];
    UICommand *y = [command commandWithTitle:@"T" image:nil action:@selector(foo:) propertyList:@{@"a": @1} alternates:@[a]];
    UICommand *z = [command commandWithTitle:@"U" image:nil action:@selector(foo:) propertyList:@{@"a": @1}];
    UICommand *w = [command commandWithTitle:@"T" image:nil action:@selector(bar:) propertyList:@{@"a": @1}];
    UICommand *v = [command commandWithTitle:@"T" image:nil action:@selector(foo:) propertyList:@{@"a": @2}];
    UICommand *u = [command commandWithTitle:@"T" image:nil action:@selector(foo:) propertyList:nil];
    NSArray *all = @[x, y, z, w, v, u];
    for (id one in all) {
        NSMutableString *row = [NSMutableString string];
        for (id other in all)
            [row appendFormat:@"%@%@ ", yes([one isEqual:other]), yes([one hash] == [other hash])];
        [lines addObject:[@"equality row " stringByAppendingString:row]];
    }
    [lines addObject:line(@"description", @[x, y, u])];
    [lines addObject:line(@"fields", @[[x title], @([x image] != nil), @([x discoverabilityTitle] != nil), @([x attributes]), @([x state]), [x alternates], [x propertyList], NSStringFromSelector([x action])])];
    [lines addObject:line(@"alternates", @[@([[y alternates] count]), @([[y alternates] firstObject] == a), @([[u alternates] count])])];
    UICommand *t = [command commandWithTitle:@"T" image:nil action:@selector(foo:) propertyList:nil];
    [t setAttributes:UIMenuElementAttributesDestructive | UIMenuElementAttributesDisabled];
    [t setState:UIMenuElementStateOn];
    [t setDiscoverabilityTitle:@"D"];
    [t setTitle:@"T2"];
    [lines addObject:line(@"after setters", @[t, @([t attributes]), @([t state]), [t discoverabilityTitle], [t title]])];
    [lines addObject:line(@"copy", @[yes([t copy] != t), yes([[t copy] isEqual:t]), @([(UICommand *)[t copy] attributes]), @([(UICommand *)[t copy] state]), [(UICommand *)[t copy] discoverabilityTitle], [(UICommand *)[t copy] title]])];
    [lines addObject:line(@"archive", archive_rows(t))];
    [lines addObject:line(@"archive with alternates", archive_rows(y))];
    [lines addObject:line(@"init", @[raised(^id { return [[command alloc] performSelector:NSSelectorFromString(@"init")]; })])];
    [lines addObject:line(@"init state", @[raised(^id { UICommand *made = [[command alloc] performSelector:NSSelectorFromString(@"init")]; return @[made.title ?: @"nil", made.image ? @"image" : @"nil", made.action ? NSStringFromSelector(made.action) : @"nil", made.propertyList ?: @"nil", @(made.alternates.count), @(made.attributes), @(made.state), made.discoverabilityTitle ?: @"nil"]; })])];
    [lines addObject:line(@"init alternate state", @[raised(^id { UICommandAlternate *made = [[alternate alloc] performSelector:NSSelectorFromString(@"init")]; return @[made.title ?: @"nil", made.action ? NSStringFromSelector(made.action) : @"nil", @(made.modifierFlags)]; })])];
    [lines addObject:line(@"nothing", @[raised(^id { return [command commandWithTitle:nil image:nil action:nil propertyList:nil]; })])];
    for (id pl in @[@"s", @1, @[@1], [NSDate dateWithTimeIntervalSince1970:5], [NSData data], @{@1: @2}, @[[NSObject new]], @{@"a": @[@{@"b": [NSNull null]}]}, [NSNull null], [NSURL URLWithString:@"http://x"], [NSMutableString stringWithString:@"m"], @{@"a": [NSMutableArray arrayWithObject:@"z"]}])
        [lines addObject:line(@"property list", @[raised(^id { UICommand *made = [command commandWithTitle:@"T" image:nil action:@selector(foo:) propertyList:pl]; return @[[made propertyList] ?: @"nil", yes([[made propertyList] isEqual:pl]), yes([[made propertyList] isKindOfClass:[NSMutableArray class]] || [[made propertyList] isKindOfClass:[NSMutableString class]])]; })])];
    UICommandAlternate *twin = [alternate alternateWithTitle:@"twin" action:@selector(foo:) modifierFlags:shift];
    UICommandAlternate *zero = [alternate alternateWithTitle:@"zero" action:@selector(foo:) modifierFlags:0];
    [lines addObject:line(@"twin alternates", @[raised(^id { return [command commandWithTitle:@"T" image:nil action:@selector(foo:) propertyList:nil alternates:@[a, twin]]; })])];
    [lines addObject:line(@"zero alternate", @[raised(^id { return [command commandWithTitle:@"T" image:nil action:@selector(foo:) propertyList:nil alternates:@[zero]]; })])];
    [lines addObject:line(@"wrong alternates", @[raised(^id { return [command commandWithTitle:@"T" image:nil action:@selector(foo:) propertyList:nil alternates:@[@1]]; })])];
    NSMutableArray *mutable = [NSMutableArray arrayWithObject:a];
    UICommand *kept = [command commandWithTitle:@"T" image:nil action:@selector(foo:) propertyList:nil alternates:mutable];
    [mutable addObject:c];
    [lines addObject:line(@"alternates are copied", @[@([[kept alternates] count])])];
    [lines addObject:line(@"responds", @[yes([command instancesRespondToSelector:@selector(alternates)]), yes([command instancesRespondToSelector:@selector(propertyList)]), yes([command instancesRespondToSelector:@selector(discoverabilityTitle)])])];
    return lines;
}

static UIImage *one_pixel_image(void)
{
    unsigned char pixels[4] = {255, 0, 0, 255};
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pixels, 1, 1, 8, 4, space, kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    CGImageRef cgImage = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    return image;
}

static NSArray *key_lines(Class key, Class command, Class alternate, UIImage *image)
{
    NSMutableArray *lines = [NSMutableArray array];
    UIKeyCommand *plain = [key keyCommandWithInput:@"a" modifierFlags:UIKeyModifierCommand action:@selector(foo:)];
    UIKeyCommand *twin = [key keyCommandWithInput:@"a" modifierFlags:UIKeyModifierCommand action:@selector(foo:)];
    [twin setTitle:@"x"];
    [twin setAttributes:1];
    UIKeyCommand *titled = [key commandWithTitle:@"tt" image:nil action:@selector(foo:) input:@"a" modifierFlags:UIKeyModifierCommand propertyList:@1];
    UIKeyCommand *shifted = [key commandWithTitle:@"tt" image:nil action:@selector(foo:) input:@"a" modifierFlags:UIKeyModifierShift propertyList:@1];
    UIKeyCommand *inputs = [key commandWithTitle:@"tt" image:nil action:@selector(foo:) input:@"b" modifierFlags:UIKeyModifierCommand propertyList:@1];
    UIKeyCommand *actions = [key commandWithTitle:@"tt" image:nil action:@selector(bar:) input:@"a" modifierFlags:UIKeyModifierCommand propertyList:@1];
    UIKeyCommand *lists = [key commandWithTitle:@"tt" image:nil action:@selector(foo:) input:@"a" modifierFlags:UIKeyModifierCommand propertyList:@2];
    NSArray *all = @[plain, twin, titled, shifted, inputs, actions, lists];
    for (id one in all) {
        NSMutableString *row = [NSMutableString string];
        for (id other in all)
            [row appendFormat:@"%@%@ ", yes([one isEqual:other]), yes([one hash] == [other hash])];
        [lines addObject:[@"equality row " stringByAppendingString:row]];
    }
    [lines addObject:line(@"plain", @[plain, [plain title], [plain input], @([plain modifierFlags]), NSStringFromSelector([plain action]), [plain propertyList] ?: @"nil", [plain alternates], [plain discoverabilityTitle] ?: @"nil"])];
    [lines addObject:line(@"titled", @[titled, [titled title], @([titled attributes]), @([titled state]), [titled propertyList]])];
    [lines addObject:line(@"init", @[raised(^id { UIKeyCommand *made = [[key alloc] performSelector:NSSelectorFromString(@"init")]; return @[made, [made input] ?: @"nil", NSStringFromSelector([made action]), [made title] ?: @"nil"]; })])];
    [lines addObject:line(@"copy", @[yes([plain copy] != plain), yes([[plain copy] isEqual:plain]), [[plain copy] input], @([[plain copy] modifierFlags]), [twin copy]])];
    [lines addObject:line(@"discoverability", @[[[key keyCommandWithInput:@"a" modifierFlags:0 action:@selector(foo:) discoverabilityTitle:@"D"] discoverabilityTitle], [[key keyCommandWithInput:@"a" modifierFlags:0 action:@selector(foo:) discoverabilityTitle:@"D"] title]])];
    [lines addObject:line(@"nothing", @[raised(^id { return [key keyCommandWithInput:@"a" modifierFlags:0 action:NULL]; }), raised(^id { return [key keyCommandWithInput:nil modifierFlags:0 action:@selector(foo:)]; })])];
    UICommandAlternate *a = [alternate alternateWithTitle:@"alt" action:@selector(foo:) modifierFlags:UIKeyModifierShift];
    [lines addObject:line(@"alternates", @[raised(^id { return [[key commandWithTitle:@"tt" image:nil action:@selector(foo:) input:@"a" modifierFlags:0 propertyList:nil alternates:@[a]] alternates]; })])];
    [lines addObject:line(@"archive", archive_rows(titled))];
    [lines addObject:line(@"archive plain", archive_rows(plain))];
    for (NSNumber *flags in @[@0, @(UIKeyModifierAlphaShift), @(UIKeyModifierShift | UIKeyModifierControl), @(UIKeyModifierAlternate | UIKeyModifierNumericPad), @(UIKeyModifierCommand | UIKeyModifierShift | UIKeyModifierAlternate | UIKeyModifierControl | UIKeyModifierAlphaShift | UIKeyModifierNumericPad)])
        [lines addObject:line(@"description flags", [key keyCommandWithInput:@"z" modifierFlags:flags.integerValue action:@selector(foo:)])];
    [lines addObject:line(@"later members", @[yes([key instancesRespondToSelector:@selector(wantsPriorityOverSystemBehavior)]), yes([key instancesRespondToSelector:@selector(allowsAutomaticLocalization)]), yes([key instancesRespondToSelector:@selector(allowsAutomaticMirroring)])])];
    [lines addObject:line(@"superclass", @[NSStringFromClass(class_getSuperclass(key)).length ? yes(class_getSuperclass(key) == command) : @""])];

    UIKeyCommand *written = [key commandWithTitle:@"before" image:nil action:@selector(foo:) input:@"i" modifierFlags:0 propertyList:nil];
    [written setTitle:@"after"];
    [written setImage:image];
    [written setDiscoverabilityTitle:@"D"];
    [written setAttributes:UIMenuElementAttributesDestructive];
    [written setState:UIMenuElementStateOn];
    [lines addObject:line(@"after setters", @[[written title], [written discoverabilityTitle], @([written attributes]), @([written state])])];
    [lines addObject:line(@"image written", @[yes([written image] == image), @([written image].size.width), @([written image].size.height), @([written image].scale)])];
    [lines addObject:line(@"image built in", @[raised(^id { UIKeyCommand *made = [key commandWithTitle:@"t" image:image action:@selector(foo:) input:@"i" modifierFlags:0 propertyList:nil]; return @[yes([made image] == image), yes([[made copy] image] == image), [made title], NSStringFromSelector([made action]), [made propertyList] ?: @"nil", [made alternates], [made discoverabilityTitle] ?: @"nil", @([made attributes]), @([made state])]; })])];
    [lines addObject:line(@"image nil", @[raised(^id { UIKeyCommand *made = [key commandWithTitle:@"t" image:nil action:@selector(foo:) input:@"i" modifierFlags:0 propertyList:nil]; [made setImage:nil]; return @[[made image] ?: @"nil", [made title]]; })])];
    [lines addObject:line(@"key properties", @[yes([key instancesRespondToSelector:@selector(title)]), yes([key instancesRespondToSelector:@selector(setTitle:)]), yes([key instancesRespondToSelector:@selector(image)]), yes([key instancesRespondToSelector:@selector(setImage:)]), yes([key instancesRespondToSelector:@selector(discoverabilityTitle)]), yes([key instancesRespondToSelector:@selector(setDiscoverabilityTitle:)]), yes([key instancesRespondToSelector:@selector(action)]), yes([key instancesRespondToSelector:@selector(propertyList)]), yes([key instancesRespondToSelector:@selector(alternates)]), yes([key instancesRespondToSelector:@selector(attributes)]), yes([key instancesRespondToSelector:@selector(setAttributes:)]), yes([key instancesRespondToSelector:@selector(state)]), yes([key instancesRespondToSelector:@selector(setState:)])])];
    return lines;
}

int main(void)
{
    @autoreleasepool {
        Class ourCommand = NSClassFromString(@"CharonHostUICommand"), ourAlternate = NSClassFromString(@"CharonHostUICommandAlternate"), ourKey = NSClassFromString(@"CharonHostUIKeyCommand");
        charon_check(ourCommand && ourAlternate && ourKey, "the port's classes are linked under their host names", @"one is missing");
        agree(@"command values", command_lines(ourCommand, ourAlternate), command_lines([UICommand class], [UICommandAlternate class]));
        UIImage *image = one_pixel_image();
        agree(@"key command values", key_lines(ourKey, ourCommand, ourAlternate, image), key_lines([UIKeyCommand class], [UICommand class], [UICommandAlternate class], image));
        UIImage *keyImage = one_pixel_image();
        UICommandAlternate *ourAlt = [ourAlternate alternateWithTitle:@"alt" action:@selector(foo:) modifierFlags:UIKeyModifierShift];
        UICommandAlternate *theirAlt = [[UICommandAlternate class] alternateWithTitle:@"alt" action:@selector(foo:) modifierFlags:UIKeyModifierShift];
        {
            UIKeyCommand *ours = [ourKey commandWithTitle:@"t7" image:keyImage action:@selector(foo:) propertyList:@"pl"];
            NSString *refusal = raised(^id {
                return ((id (*)(Class, SEL, id, id, SEL, id))objc_msgSend)([UIKeyCommand class],
                           NSSelectorFromString(@"commandWithTitle:image:action:propertyList:"), @"t7", keyImage, @selector(foo:), @"pl");
            });
            NSString *answer = [NSString stringWithFormat:@"%@ title %@ action %@ propertyList %@ image %@ input %@ flags %lu",
                                NSStringFromClass([ours class]), [ours title], NSStringFromSelector([ours action]), [ours propertyList] ?: @"nil",
                                [ours image] == keyImage ? @"kept" : @"lost", [ours input] ?: @"nil", (unsigned long)[ours modifierFlags]];
            charon_check(ours != nil && [answer hasPrefix:@"CharonHostUIKeyCommand"] && [refusal hasPrefix:@"raised"],
                         "the factory of 7.0 answers on the port, and the host has no answer to compare with",
                         [NSString stringWithFormat:@"port %@ | host %@", answer, refusal]);
        }
        {
            UIKeyCommand *ours = [ourKey commandWithTitle:@"t8" image:nil action:@selector(foo:) propertyList:nil alternates:@[ourAlt]];
            NSString *refusal = raised(^id {
                return ((id (*)(Class, SEL, id, id, SEL, id, id))objc_msgSend)([UIKeyCommand class],
                           NSSelectorFromString(@"commandWithTitle:image:action:propertyList:alternates:"), @"t8", nil, @selector(foo:), nil, @[theirAlt]);
            });
            NSString *answer = [NSString stringWithFormat:@"%@ title %@ alternates %lu action %@",
                                NSStringFromClass([ours class]), [ours title], (unsigned long)[ours alternates].count, NSStringFromSelector([ours action])];
            charon_check(ours != nil && [answer hasPrefix:@"CharonHostUIKeyCommand"] && [ours alternates].count == 1 && [refusal hasPrefix:@"raised"],
                         "the factory of 7.0 with alternates answers on the port, and the host has none",
                         [NSString stringWithFormat:@"port %@ | host %@", answer, refusal]);
        }
        charon_check([[NSString stringWithUTF8String:class_getName(class_getSuperclass(ourKey))] isEqualToString:@"CharonHostUICommand"], "a key command is a command", @"it is not");
        charon_check(![ourCommand instancesRespondToSelector:@selector(subtitle)] && ![ourCommand instancesRespondToSelector:@selector(selectedImage)] && ![ourCommand instancesRespondToSelector:@selector(repeatBehavior)] &&
                         ![ourCommand instancesRespondToSelector:@selector(sender)] && ![ourCommand instancesRespondToSelector:@selector(performWithSender:target:)],
                     "a command answers none of the members of iOS 16 and later", @"it answers one");
        charon_check([ourCommand supportsSecureCoding] && [ourAlternate supportsSecureCoding] && [ourKey supportsSecureCoding], "the classes support secure coding", @"one does not");
        NSString *ourTag = *(NSString *const *)dlsym(RTLD_DEFAULT, "CharonHostUICommandTagShare");
        charon_check([ourTag isEqualToString:UICommandTagShare], "the share tag is the system's", @"it differs");
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        return charon_failures ? 1 : 0;
    }
}
