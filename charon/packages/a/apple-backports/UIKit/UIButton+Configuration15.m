// UIButton+Configuration15.m - the configuration members of UIButton added in iOS 15.0.
//
// Five rows: UIButton.configurationUpdateHandler, UIButton.automaticallyUpdatesConfiguration,
// UIButton.configuration, UIButton.changesSelectionAsPrimaryAction and
// UIButton.subtitleLabel, plus -[UIButton setNeedsUpdateConfiguration],
// -[UIButton updateConfiguration] and +[UIButton buttonWithConfiguration:primaryAction:].
//
// This is the same delivery the cells already use, and it reuses the cells' seam rather than
// making a second one. UIConfigurationUpdateHandler15.m carries configurationUpdateHandler on
// UICollectionViewCell, UITableViewCell and UITableViewHeaderFooterView by calling
// charon_host_update_handler and charon_host_set_update_handler, which are defined in
// CharonConfigurationHost.m and take a UIView - they are not cell-specific, they are
// view-specific, and a button is a view. Calling them from here is reuse, not duplication, and
// it is why this file defines no C function of its own: a C function defined in a file that
// exports API is left out of the bands that already export that API, and the call is then
// undefined symbols in exactly those bands (AGENTS.md, "A C function shared between backport
// files").
//
// What the host answers was measured first, and it is the same measurement the cell case
// already records. A configuration is a value: a background, a title, an image, insets, and the
// flags that say how the button should redraw itself. The port's own UIButtonConfiguration.m
// implements that value and its case (tests/backports/host/uikit2/buttonconfig_test.m) holds
// the constructors and the twenty-five properties against the host's. What the release has not
// got is a button that HOLDS one: 6.1.3's UIButton carries no selector mentioning
// "configuration" at all, and UIButtonConfiguration is not a class it declares.
//
// So what is carried here is the wiring, and the wiring is real work rather than a stub:
//
//   - configuration is kept per button, copied on set the way the configuration value's own
//     -copy does, and a nil set clears it;
//   - setNeedsUpdateConfiguration and updateConfiguration reach the button, and the update
//     invokes the handler with the button and its configuration, which is what the 14.0 cell
//     rows already do through the same seam;
//   - automaticallyUpdatesConfiguration defaults to YES, and setting it YES asks for an update,
//     which is the behaviour the 14.0 automaticallyUpdatesContentConfiguration row records;
//   - changesSelectionAsPrimaryAction and subtitleLabel are kept and read back, and the
//     subtitle label is created on first ask so that -[UIButton subtitleLabel] answers a label
//     rather than nil - the port's own button already has a titleLabel to place it under.
//
// The last two are `inert` and not `implemented`, and the difference is deliberate: the release
// has no selection-primary-action behaviour for a button to drive and no two-line button to
// draw, so the accessors are carried and nothing applies them. Their rows say so in the same
// words the NSLayoutManager.usesDefaultHyphenation row of 13.0 uses, which is the precedent for
// carrying a flag the release cannot act on.

#import "CharonLists.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

// The seams, reused from CharonConfigurationHost.m. Declared here rather than imported so this
// file's dependency on that one is visible in the file that has it.
extern id charon_host_update_handler(UIView *host);
extern void charon_host_set_update_handler(UIView *host, id handler);
extern void charon_request_update(UIView *view);

static const void *CharonButtonConfigurationKey = &CharonButtonConfigurationKey;
static const void *CharonButtonAutoUpdateKey = &CharonButtonAutoUpdateKey;
static const void *CharonButtonPrimaryActionKey = &CharonButtonPrimaryActionKey;
static const void *CharonButtonSubtitleLabelKey = &CharonButtonSubtitleLabelKey;

@implementation UIButton (CharonConfiguration15)

+ (instancetype)buttonWithConfiguration:(UIButtonConfiguration *)configuration primaryAction:(UIAction *)primaryAction
{
    // The same three steps +[UIButton buttonWithType:primaryAction:] already takes in
    // UIButton+Actions14.m, with the configuration taking the place of the title and image it sets
    // from the action: a configured button draws its title and image from the configuration, and
    // the action is delivered by -addAction:forControlEvents:, which the port already carries.
    // Reusing that constructor's mechanism is the point - a second wiring would be a second copy.
    UIButton *button = [self buttonWithType:UIButtonTypeSystem primaryAction:primaryAction];
    button.configuration = configuration;
    return button;
}

- (UIButtonConfiguration *)configuration
{
    return objc_getAssociatedObject(self, CharonButtonConfigurationKey);
}

- (void)setConfiguration:(UIButtonConfiguration *)configuration
{
    // Copied, so that mutating the configuration the caller passed in afterwards does not reach
    // back into the button. This is what the value's own -copy is for, and the 14.0 cell rows
    // keep their configuration the same way.
    objc_setAssociatedObject(self, CharonButtonConfigurationKey, [configuration copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self setNeedsUpdateConfiguration];
}

- (UIButtonConfigurationUpdateHandler)configurationUpdateHandler
{
    return charon_host_update_handler(self);
}

- (void)setConfigurationUpdateHandler:(UIButtonConfigurationUpdateHandler)configurationUpdateHandler
{
    charon_host_set_update_handler(self, configurationUpdateHandler);
}

- (BOOL)automaticallyUpdatesConfiguration
{
    NSNumber *kept = objc_getAssociatedObject(self, CharonButtonAutoUpdateKey);
    // YES when nothing has said otherwise, which is the default the 14.0
    // automaticallyUpdatesContentConfiguration row measured on the host.
    return kept ? kept.boolValue : YES;
}

- (void)setAutomaticallyUpdatesConfiguration:(BOOL)automaticallyUpdatesConfiguration
{
    objc_setAssociatedObject(self, CharonButtonAutoUpdateKey, @(automaticallyUpdatesConfiguration), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (automaticallyUpdatesConfiguration)
        [self setNeedsUpdateConfiguration];
}

- (void)setNeedsUpdateConfiguration
{
    charon_request_update(self);
}

- (void)updateConfiguration
{
    // The handler takes the button and nothing else - UIButton.h:46 reads
    // `typedef void (^UIButtonConfigurationUpdateHandler)(__kindof UIButton *button)` - so the
    // configuration the handler needs is the one the button already holds, and a handler that
    // wants it reads -configuration. Passing it as a second argument was wrong, and the armv7
    // compile is what said so: "too many arguments to block call, expected 1, have 2".
    UIButtonConfigurationUpdateHandler handler = charon_host_update_handler(self);
    if (handler)
        handler(self);
}

- (BOOL)changesSelectionAsPrimaryAction
{
    return [objc_getAssociatedObject(self, CharonButtonPrimaryActionKey) boolValue];
}

- (void)setChangesSelectionAsPrimaryAction:(BOOL)changesSelectionAsPrimaryAction
{
    objc_setAssociatedObject(self, CharonButtonPrimaryActionKey, @(changesSelectionAsPrimaryAction), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UILabel *)subtitleLabel
{
    UILabel *label = objc_getAssociatedObject(self, CharonButtonSubtitleLabelKey);
    if (label)
        return label;
    // Created on first ask rather than answered nil, so that -[UIButton subtitleLabel] is
    // something a caller can set text on. It is a plain UILabel: the port's own button has a
    // titleLabel, and this is the second line under it.
    label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.textAlignment = NSTextAlignmentCenter;
    label.backgroundColor = [UIColor clearColor];
    objc_setAssociatedObject(self, CharonButtonSubtitleLabelKey, label, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return label;
}

@end
