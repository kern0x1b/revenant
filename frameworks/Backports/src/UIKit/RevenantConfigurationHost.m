#import "RevenantLists.h"
#import <objc/runtime.h>
#import <objc/message.h>

static const char RevenantHostKey;
static const char RevenantTableStyleKey;
static const char RevenantUpdateHandlerKey;

@interface RevenantBackgroundView : UIView
- (void)revenant_applyConfiguration:(UIBackgroundConfiguration *)configuration inBounds:(CGRect)bounds tint:(UIColor *)tint;
@end

@implementation RevenantBackgroundView {
    UIVisualEffectView *_effectView;
    UIView *_customView;
}

- (void)revenant_applyConfiguration:(UIBackgroundConfiguration *)configuration inBounds:(CGRect)bounds tint:(UIColor *)tint
{
    NSDirectionalEdgeInsets insets = configuration.backgroundInsets;
    CGRect frame = CGRectMake(bounds.origin.x + insets.leading, bounds.origin.y + insets.top, bounds.size.width - insets.leading - insets.trailing, bounds.size.height - insets.top - insets.bottom);
    CGFloat outset = configuration.strokeWidth > 0 ? configuration.strokeOutset : 0;
    self.frame = CGRectInset(frame, -outset, -outset);
    UIColor *color = [configuration resolvedBackgroundColorForTintColor:tint];
    self.backgroundColor = color ?: [UIColor clearColor];
    self.layer.cornerRadius = configuration.cornerRadius;
    self.layer.masksToBounds = configuration.cornerRadius > 0 || configuration.visualEffect != nil;
    UIColor *stroke = configuration.strokeWidth > 0 ? [configuration resolvedStrokeColorForTintColor:tint] : nil;
    self.layer.borderWidth = stroke ? configuration.strokeWidth : 0;
    self.layer.borderColor = stroke.CGColor;
    if (configuration.visualEffect) {
        if (!_effectView) {
            _effectView = [[UIVisualEffectView alloc] initWithEffect:configuration.visualEffect];
            _effectView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [self insertSubview:_effectView atIndex:0];
        }
        _effectView.effect = configuration.visualEffect;
        _effectView.frame = self.bounds;
    } else {
        [_effectView removeFromSuperview];
        _effectView = nil;
    }
    if (configuration.customView != _customView) {
        [_customView removeFromSuperview];
        _customView = configuration.customView;
        if (_customView) {
            [_customView removeFromSuperview];
            _customView.frame = self.bounds;
            _customView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [self addSubview:_customView];
        }
    } else {
        _customView.frame = self.bounds;
    }
}

@end

@interface RevenantHostState : NSObject {
@public
    id<UIContentConfiguration> content;
    UIView<UIContentView> *contentView;
    UIBackgroundConfiguration *background;
    RevenantBackgroundView *backgroundView;
    BOOL manualContent, manualBackground, needsUpdate, updating;
    BOOL savedStyle;
    NSInteger selectionStyle;
    NSMutableArray *hidden;
}
@end

@implementation RevenantHostState
@end

static RevenantHostState *revenant_state(UIView *host, BOOL create)
{
    RevenantHostState *state = objc_getAssociatedObject(host, &RevenantHostKey);
    if (!state && create) {
        state = [[RevenantHostState alloc] init];
        state->needsUpdate = YES;
        objc_setAssociatedObject(host, &RevenantHostKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return state;
}

UIView *revenant_host_content_view(UIView *host)
{
    if ([host isKindOfClass:[UICollectionViewCell class]])
        return ((UICollectionViewCell *)host).contentView;
    if ([host isKindOfClass:[UITableViewCell class]])
        return ((UITableViewCell *)host).contentView;
    if ([host isKindOfClass:[UITableViewHeaderFooterView class]])
        return ((UITableViewHeaderFooterView *)host).contentView;
    return host;
}

UICollectionView *revenant_owning_collection_view(UIView *view)
{
    UIView *candidate = view.superview;
    while (candidate && ![candidate isKindOfClass:[UICollectionView class]])
        candidate = candidate.superview;
    return (UICollectionView *)candidate;
}

id<UIContentConfiguration> revenant_host_content(UIView *host)
{
    RevenantHostState *state = revenant_state(host, NO);
    return state ? [state->content copyWithZone:nil] : nil;
}

static void revenant_install_content(UIView *host, RevenantHostState *state, id<UIContentConfiguration> configuration)
{
    state->content = [configuration copyWithZone:nil];
    UIView *container = revenant_host_content_view(host);
    if (!configuration) {
        [state->contentView removeFromSuperview];
        state->contentView = nil;
        return;
    }
    UIView<UIContentView> *made = [configuration makeContentView];
    if (state->contentView && [state->contentView class] == [made class]) {
        state->contentView.configuration = configuration;
        return;
    }
    [state->contentView removeFromSuperview];
    state->contentView = made;
    made.frame = container.bounds;
    made.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [container addSubview:made];
    [host setNeedsLayout];
}

void revenant_host_set_content(UIView *host, id<UIContentConfiguration> configuration)
{
    revenant_install_content(host, revenant_state(host, YES), configuration);
}

UIBackgroundConfiguration *revenant_host_background(UIView *host)
{
    RevenantHostState *state = revenant_state(host, NO);
    return state ? [state->background copy] : nil;
}

static void revenant_restore_backgrounds(UIView *host, RevenantHostState *state)
{
    for (UIView *view in state->hidden)
        view.hidden = NO;
    state->hidden = nil;
    if (state->savedStyle && [host isKindOfClass:[UITableViewCell class]])
        ((UITableViewCell *)host).selectionStyle = (UITableViewCellSelectionStyle)state->selectionStyle;
    state->savedStyle = NO;
}

static void revenant_install_background(UIView *host, RevenantHostState *state, UIBackgroundConfiguration *configuration)
{
    state->background = [configuration copy];
    if (!configuration) {
        [state->backgroundView removeFromSuperview];
        state->backgroundView = nil;
        revenant_restore_backgrounds(host, state);
        return;
    }
    if (!state->backgroundView) {
        state->backgroundView = [[RevenantBackgroundView alloc] init];
        UIView *container = revenant_host_content_view(host);
        [host insertSubview:state->backgroundView belowSubview:container];
        state->hidden = [NSMutableArray array];
        UIView *plain = nil, *selected = nil;
        if ([host isKindOfClass:[UICollectionViewCell class]]) {
            plain = ((UICollectionViewCell *)host).backgroundView;
            selected = ((UICollectionViewCell *)host).selectedBackgroundView;
        } else if ([host isKindOfClass:[UITableViewCell class]]) {
            plain = ((UITableViewCell *)host).backgroundView;
            selected = ((UITableViewCell *)host).selectedBackgroundView;
            state->savedStyle = YES;
            state->selectionStyle = ((UITableViewCell *)host).selectionStyle;
            ((UITableViewCell *)host).selectionStyle = UITableViewCellSelectionStyleNone;
        }
        for (UIView *view in @[plain ?: (id)[NSNull null], selected ?: (id)[NSNull null]])
            if ([view isKindOfClass:[UIView class]] && !view.hidden) {
                view.hidden = YES;
                [state->hidden addObject:view];
            }
    }
    [state->backgroundView revenant_applyConfiguration:configuration inBounds:host.bounds tint:host.tintColor];
}

void revenant_host_set_background(UIView *host, UIBackgroundConfiguration *configuration)
{
    revenant_install_background(host, revenant_state(host, YES), configuration);
}

BOOL revenant_host_automatic(UIView *host, BOOL background)
{
    RevenantHostState *state = revenant_state(host, NO);
    return !state || !(background ? state->manualBackground : state->manualContent);
}

void revenant_host_set_automatic(UIView *host, BOOL background, BOOL automatic)
{
    RevenantHostState *state = revenant_state(host, YES);
    if (background)
        state->manualBackground = !automatic;
    else
        state->manualContent = !automatic;
}

void revenant_host_default_update(UIView *host, UIViewConfigurationState *viewState)
{
    RevenantHostState *state = revenant_state(host, YES);
    if (!state->manualContent && state->content)
        revenant_install_content(host, state, [state->content updatedConfigurationForState:viewState]);
    if (!state->manualBackground && state->background)
        revenant_install_background(host, state, [state->background updatedConfigurationForState:viewState]);
}

NSNumber *revenant_host_table_style(UITableViewCell *cell)
{
    return objc_getAssociatedObject(cell, &RevenantTableStyleKey);
}

@implementation UIView (RevenantListHost)

- (UIView *)revenant_configurationContainer
{
    return revenant_host_content_view(self);
}

- (UIViewConfigurationState *)revenant_makeConfigurationState
{
    UITraitCollection *traits = [self respondsToSelector:@selector(traitCollection)] ? self.traitCollection : nil;
    if (!traits)
        traits = [[UITraitCollection alloc] init];
    BOOL header = [self isKindOfClass:[UITableViewHeaderFooterView class]];
    UIViewConfigurationState *state = header ? [[UIViewConfigurationState alloc] initWithTraitCollection:traits] : [[UICellConfigurationState alloc] initWithTraitCollection:traits];
    state.disabled = !self.userInteractionEnabled;
    if ([self isKindOfClass:[UICollectionViewCell class]]) {
        UICollectionViewCell *cell = (UICollectionViewCell *)self;
        state.selected = cell.selected;
        state.highlighted = cell.highlighted;
        [(UICellConfigurationState *)state setEditing:[revenant_owning_collection_view(self) revenant_editing]];
        if ([self respondsToSelector:@selector(revenant_isExpanded)])
            [(UICellConfigurationState *)state setExpanded:[(UICollectionViewListCell *)self revenant_isExpanded]];
    } else if ([self isKindOfClass:[UITableViewCell class]]) {
        UITableViewCell *cell = (UITableViewCell *)self;
        state.selected = cell.selected;
        state.highlighted = cell.highlighted;
        [(UICellConfigurationState *)state setEditing:[[cell valueForKey:@"editing"] boolValue]];
    }
    return state;
}

- (void)revenant_setNeedsUpdateConfiguration
{
    revenant_state(self, YES)->needsUpdate = YES;
    [self setNeedsLayout];
}

- (void)revenant_layoutWillRun
{
    RevenantHostState *state = revenant_state(self, YES);
    if (!state->needsUpdate || state->updating)
        return;
    state->needsUpdate = NO;
    state->updating = YES;
    UIViewConfigurationState *configurationState = [self revenant_makeConfigurationState];
    ((void (*)(id, SEL, id))objc_msgSend)(self, @selector(updateConfigurationUsingState:), configurationState);
    void (^handler)(id, id) = objc_getAssociatedObject(self, &RevenantUpdateHandlerKey);
    if (handler)
        handler(self, configurationState);
    state->updating = NO;
}

- (void)revenant_layoutDidRun
{
    RevenantHostState *state = revenant_state(self, NO);
    if (!state)
        return;
    if (state->backgroundView)
        [state->backgroundView revenant_applyConfiguration:state->background inBounds:self.bounds tint:self.tintColor];
    if (state->contentView && state->contentView.superview == revenant_host_content_view(self))
        state->contentView.frame = revenant_host_content_view(self).bounds;
}

@end

void revenant_request_update(UIView *view)
{
    ((void (*)(id, SEL))objc_msgSend)(view, @selector(setNeedsUpdateConfiguration));
}

id revenant_host_update_handler(UIView *host)
{
    return objc_getAssociatedObject(host, &RevenantUpdateHandlerKey);
}

void revenant_host_set_update_handler(UIView *host, id handler)
{
    objc_setAssociatedObject(host, &RevenantUpdateHandlerKey, [handler copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    revenant_request_update(host);
}

static void revenant_wrap(Class cls, SEL selector, id (^make)(IMP original))
{
    Method method = class_getInstanceMethod(cls, selector);
    if (!method)
        return;
    IMP original = method_getImplementation(method);
    class_replaceMethod(cls, selector, imp_implementationWithBlock(make(original)), method_getTypeEncoding(method));
}

@interface RevenantConfigurationHooks : NSObject
@end

@implementation RevenantConfigurationHooks

+ (void)load
{
    Class collection = [UICollectionViewCell class], table = [UITableViewCell class], header = [UITableViewHeaderFooterView class];
    revenant_wrap(collection, @selector(setSelected:), ^id(IMP original) {
        return ^(UICollectionViewCell *self_, BOOL value) {
            ((void (*)(id, SEL, BOOL))original)(self_, @selector(setSelected:), value);
            revenant_request_update(self_);
        };
    });
    revenant_wrap(collection, @selector(setHighlighted:), ^id(IMP original) {
        return ^(UICollectionViewCell *self_, BOOL value) {
            ((void (*)(id, SEL, BOOL))original)(self_, @selector(setHighlighted:), value);
            revenant_request_update(self_);
        };
    });
    revenant_wrap(table, @selector(setSelected:animated:), ^id(IMP original) {
        return ^(UITableViewCell *self_, BOOL value, BOOL animated) {
            ((void (*)(id, SEL, BOOL, BOOL))original)(self_, @selector(setSelected:animated:), value, animated);
            revenant_request_update(self_);
        };
    });
    revenant_wrap(table, @selector(setHighlighted:animated:), ^id(IMP original) {
        return ^(UITableViewCell *self_, BOOL value, BOOL animated) {
            ((void (*)(id, SEL, BOOL, BOOL))original)(self_, @selector(setHighlighted:animated:), value, animated);
            revenant_request_update(self_);
        };
    });
    revenant_wrap(table, NSSelectorFromString(@"setEditing:animated:"), ^id(IMP original) {
        return ^(UITableViewCell *self_, BOOL value, BOOL animated) {
            ((void (*)(id, SEL, BOOL, BOOL))original)(self_, NSSelectorFromString(@"setEditing:animated:"), value, animated);
            revenant_request_update(self_);
        };
    });
    revenant_wrap(table, @selector(initWithStyle:reuseIdentifier:), ^id(IMP original) {
        return ^(UITableViewCell *self_, UITableViewCellStyle style, NSString *identifier) {
            UITableViewCell *cell = ((id (*)(id, SEL, UITableViewCellStyle, NSString *))original)(self_, @selector(initWithStyle:reuseIdentifier:), style, identifier);
            objc_setAssociatedObject(cell, &RevenantTableStyleKey, @(style), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return cell;
        };
    });
    for (Class cls in @[table, header]) {
        for (NSString *name in @[@"textLabel", @"detailTextLabel", @"imageView"]) {
            SEL selector = NSSelectorFromString(name);
            if (cls == header && [name isEqual:@"imageView"])
                continue;
            revenant_wrap(cls, selector, ^id(IMP original) {
                return ^id(UIView *self_) {
                    return revenant_host_content(self_) ? nil : ((id (*)(id, SEL))original)(self_, selector);
                };
            });
        }
    }
    for (Class cls in @[collection, table, header]) {
        revenant_wrap(cls, @selector(layoutSubviews), ^id(IMP original) {
            return ^(UIView *self_) {
                [self_ revenant_layoutWillRun];
                ((void (*)(id, SEL))original)(self_, @selector(layoutSubviews));
                [self_ revenant_layoutDidRun];
            };
        });
    }
}

@end
