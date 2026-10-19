#import <UIKit/UIKit.h>
#import <SafariServices/SafariServices.h>
#import "check.h"

@interface CharonHostSFSafariViewController : UIViewController
@property (nonatomic, weak) id delegate;
@property (nonatomic, readonly, copy) id configuration;
@property (nonatomic) UIColor *preferredBarTintColor;
@property (nonatomic) UIColor *preferredControlTintColor;
@property (nonatomic) NSInteger dismissButtonStyle;
- (instancetype)initWithURL:(NSURL *)URL;
- (instancetype)initWithURL:(NSURL *)URL entersReaderIfAvailable:(BOOL)reader;
- (instancetype)initWithURL:(NSURL *)URL configuration:(id)configuration;
+ (id)prewarmConnectionsToURLs:(NSArray *)URLs;
@end

@interface CharonHostSFSafariViewControllerConfiguration : NSObject <NSCopying>
@property (nonatomic) BOOL entersReaderIfAvailable;
@property (nonatomic) BOOL barCollapsingEnabled;
@property (nonatomic, copy) id activityButton;
@end

@interface CharonHostSFSafariViewControllerActivityButton : NSObject <NSCopying, NSSecureCoding>
- (instancetype)initWithTemplateImage:(UIImage *)image extensionIdentifier:(NSString *)identifier;
@property (nonatomic, readonly, copy) UIImage *templateImage;
@property (nonatomic, readonly, copy) NSString *extensionIdentifier;
@end

@interface CharonHostSFAuthenticationSession : NSObject
- (instancetype)initWithURL:(NSURL *)URL callbackURLScheme:(NSString *)scheme completionHandler:(void (^)(NSURL *, NSError *))handler;
- (BOOL)start;
- (void)cancel;
@end

static NSString *outcome(id (^block)(void))
{
    @try {
        id value = block();
        return value ? @"made" : @"nil";
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"raises %@: %@", exception.name, exception.reason];
    }
}

static NSString *state(id controller)
{
    id configuration = [controller configuration];
    return [NSString stringWithFormat:@"delegate=%d bar=%d control=%d loaded=%d configuration=%@ reader=%d collapsing=%d title=%@ initial=%@", [controller delegate] != nil, [controller preferredBarTintColor] != nil,
            [controller preferredControlTintColor] != nil, [controller isViewLoaded], configuration ? @"present" : @"nil", [configuration entersReaderIfAvailable], [configuration barCollapsingEnabled],
            [controller title], [[controller performSelector:NSSelectorFromString(@"initialURL")] absoluteString]];
}

int main(void)
{
    @autoreleasepool {
        Class system = [SFSafariViewController class], ours = [CharonHostSFSafariViewController class];
        NSArray *addresses = @[@"http://example.com", @"https://example.com/a?b#c", @"HTTPS://EXAMPLE.COM", @"Http://x.y", @"ftp://x.com", @"file:///tmp/a", @"about:blank", @"example.com", @"mailto:a@b.c", @"javascript:alert(1)", @"data:text/html,x", @""];
        for (NSString *address in addresses) {
            NSURL *URL = [NSURL URLWithString:address];
            NSString *name = [NSString stringWithFormat:@"initWithURL: %@", address];
            CHECK_EQUAL(outcome(^{ return [[ours alloc] initWithURL:URL]; }), outcome(^{ return [[system alloc] initWithURL:URL]; }), name.UTF8String);
            name = [NSString stringWithFormat:@"initWithURL:entersReaderIfAvailable: %@", address];
            CHECK_EQUAL(outcome(^{ return [[ours alloc] initWithURL:URL entersReaderIfAvailable:YES]; }), outcome(^{ return [[system alloc] initWithURL:URL entersReaderIfAvailable:YES]; }), name.UTF8String);
        }
        CHECK_EQUAL(outcome(^{ return [[ours alloc] initWithURL:nil]; }), outcome(^{ return [[system alloc] initWithURL:nil]; }), "a nil URL is refused as an unsupported scheme");
        CHECK_EQUAL(outcome(^{ return [[ours alloc] performSelector:NSSelectorFromString(@"init")]; }), outcome(^{ return [[system alloc] performSelector:NSSelectorFromString(@"init")]; }), "init is misuse");
        CHECK_EQUAL(outcome(^{ return [ours performSelector:NSSelectorFromString(@"new")]; }), outcome(^{ return [system performSelector:NSSelectorFromString(@"new")]; }), "new is misuse");
        CHECK_EQUAL(outcome(^{ return [[ours alloc] initWithNibName:nil bundle:nil]; }), outcome(^{ return [[system alloc] initWithNibName:nil bundle:nil]; }), "a nib is misuse");

        NSURL *page = [NSURL URLWithString:@"https://example.com/page"];
        CHECK_EQUAL(state([[ours alloc] initWithURL:page]), state([[system alloc] initWithURL:page]), "a new controller has the defaults of the system's");
        CHECK_EQUAL(state([[ours alloc] initWithURL:page entersReaderIfAvailable:YES]), state([[system alloc] initWithURL:page entersReaderIfAvailable:YES]), "the reader flag lands in the configuration");
        CHECK_EQUAL(state([[ours alloc] initWithURL:page configuration:nil]), state([[system alloc] initWithURL:page configuration:nil]), "no configuration leaves none");

        Class systemConfiguration = [SFSafariViewControllerConfiguration class], ourConfiguration = [CharonHostSFSafariViewControllerConfiguration class];
        id (^configured)(Class, Class, BOOL, BOOL) = ^id(Class configurationClass, Class controllerClass, BOOL reader, BOOL collapsing) {
            id configuration = [[configurationClass alloc] init];
            [configuration setEntersReaderIfAvailable:reader];
            [configuration setBarCollapsingEnabled:collapsing];
            id controller = [[controllerClass alloc] initWithURL:page configuration:configuration];
            [configuration setEntersReaderIfAvailable:!reader];
            return [NSString stringWithFormat:@"%@ same=%d copyOfConfiguration=%d", state(controller), [controller configuration] == configuration, [[controller configuration] isEqual:configuration]];
        };
        CHECK_EQUAL(configured(ourConfiguration, ours, YES, NO), configured(systemConfiguration, system, YES, NO), "the configuration is copied when it is given");
        CHECK_EQUAL(configured(ourConfiguration, ours, NO, YES), configured(systemConfiguration, system, NO, YES), "and later changes to it are not seen");

        id (^settings)(Class) = ^id(Class controllerClass) {
            id controller = [[controllerClass alloc] initWithURL:page];
            [controller setPreferredBarTintColor:[UIColor redColor]];
            [controller setDismissButtonStyle:2];
            [controller setDelegate:controller];
            return [NSString stringWithFormat:@"style=%ld delegate=%d", (long)[controller dismissButtonStyle], [controller delegate] != nil];
        };
        CHECK_EQUAL(settings(ours), settings(system), "the dismiss style and the delegate are kept");

        id defaults = [[ourConfiguration alloc] init], theirs = [[systemConfiguration alloc] init];
        CHECK_EQUAL(([NSString stringWithFormat:@"%d %d %d", [defaults entersReaderIfAvailable], [defaults barCollapsingEnabled], [defaults activityButton] != nil]),
                    ([NSString stringWithFormat:@"%d %d %d", [theirs entersReaderIfAvailable], [theirs barCollapsingEnabled], [theirs activityButton] != nil]), "a new configuration has the defaults of the system's");
        CHECK([[defaults copy] isKindOfClass:ourConfiguration] && [[theirs copy] isKindOfClass:systemConfiguration], "a configuration copies as itself");

        CHECK_EQUAL(outcome(^{ return [ours prewarmConnectionsToURLs:@[page]]; }), outcome(^{ return [system prewarmConnectionsToURLs:@[page]]; }), "prewarming answers a token");
        CHECK_EQUAL(outcome(^{ return [ours prewarmConnectionsToURLs:@[]]; }), outcome(^{ return [system prewarmConnectionsToURLs:@[]]; }), "even for nothing");
        id token = [ours prewarmConnectionsToURLs:@[page]];
        CHECK_EQUAL(outcome(^{ [token invalidate]; [token invalidate]; return token; }), @"made", "a token can be invalidated twice");

        UIImage *image = [[UIImage alloc] init];
        id button = [[CharonHostSFSafariViewControllerActivityButton alloc] initWithTemplateImage:image extensionIdentifier:@"x.y"];
        id copy = [button copy];
        CHECK([[copy extensionIdentifier] isEqualToString:@"x.y"] && [copy templateImage] == image, "an activity button keeps and copies its image and extension");
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:button requiringSecureCoding:YES error:NULL];
        id decoded = [NSKeyedUnarchiver unarchivedObjectOfClass:[CharonHostSFSafariViewControllerActivityButton class] fromData:data error:NULL];
        CHECK([[decoded extensionIdentifier] isEqualToString:@"x.y"], "and survives a secure archive");
        Class systemSession = [SFAuthenticationSession class], ourSession = [CharonHostSFAuthenticationSession class];
        NSString *(^session)(Class, NSString *, NSString *, int) = ^NSString *(Class sessionClass, NSString *address, NSString *scheme, int script) {
            NSMutableArray *log = [NSMutableArray array];
            CharonHostSFAuthenticationSession *made = [[sessionClass alloc] initWithURL:address.length ? [NSURL URLWithString:address] : nil callbackURLScheme:scheme completionHandler:^(NSURL *URL, NSError *error) {
                [log addObject:[NSString stringWithFormat:@"handler url=%@ error=%@/%ld/%@", URL, error.domain, (long)error.code, error.userInfo ?: @"none"]];
            }];
            if (script == 1)
                [made cancel];
            [log addObject:[NSString stringWithFormat:@"start=%d", [made start]]];
            if (script == 2)
                [log addObject:[NSString stringWithFormat:@"again=%d", [made start]]];
            return [log componentsJoinedByString:@" | "];
        };
        for (NSString *address in @[@"https://example.com/login", @"ftp://example.com", @"example.com", @"", @"myapp://x"]) {
            for (int script = 0; script < 3; script++) {
                NSString *name = [NSString stringWithFormat:@"a session for %@, script %d", address, script];
                CHECK_EQUAL(session(ourSession, address, @"myapp", script), session(systemSession, address, @"myapp", script), name.UTF8String);
            }
        }
        CHECK_EQUAL(session(ourSession, @"https://example.com", nil, 0), session(systemSession, @"https://example.com", nil, 0), "no scheme is accepted");
        CHECK_EQUAL(outcome(^{ return [[ourSession alloc] performSelector:NSSelectorFromString(@"init")]; }), outcome(^{ return [[systemSession alloc] performSelector:NSSelectorFromString(@"init")]; }), "init of a session");
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    }
    return charon_failures;
}
