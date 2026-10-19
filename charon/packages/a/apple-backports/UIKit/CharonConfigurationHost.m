#import "CharonLists.h"
#import <objc/runtime.h>
#import <objc/message.h>

static const char CharonHostKey;
static const char CharonTableStyleKey;
static const char CharonUpdateHandlerKey;

@interface CharonBackgroundView : UIView
- (void)charon_applyConfiguration:(UIBackgroundConfiguration *)configuration inBounds:(CGRect)bounds tint:(UIColor *)tint;
@end

@implementation CharonBackgroundView {
    UIVisualEffectView *_effectView;
    UIView *_customView;
}

- (void)charon_applyConfiguration:(UIBackgroundConfiguration *)configuration inBounds:(CGRect)bounds tint:(UIColor *)tint
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

@interface CharonHostState : NSObject {
@public
    id<UIContentConfiguration> content;
    UIView<UIContentView> *contentView;
    UIBackgroundConfiguration *background;
    CharonBackgroundView *backgroundView;
    BOOL manualContent, manualBackground, needsUpdate, updating;
    BOOL savedStyle;
    NSInteger selectionStyle;
    NSMutableArray *hidden;
}
@end

@implementation CharonHostState
@end

static CharonHostState *charon_state(UIView *host, BOOL create)
{
    CharonHostState *state = objc_getAssociatedObject(host, &CharonHostKey);
    if (!state && create) {
        state = [[CharonHostState alloc] init];
        state->needsUpdate = YES;
        objc_setAssociatedObject(host, &CharonHostKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return state;
}

UIView *charon_host_content_view(UIView *host)
{
    if ([host isKindOfClass:[UICollectionViewCell class]])
        return ((UICollectionViewCell *)host).contentView;
    if ([host isKindOfClass:[UITableViewCell class]])
        return ((UITableViewCell *)host).contentView;
    if ([host isKindOfClass:[UITableViewHeaderFooterView class]])
        return ((UITableViewHeaderFooterView *)host).contentView;
    return host;
}

UICollectionView *charon_owning_collection_view(UIView *view)
{
    UIView *candidate = view.superview;
    while (candidate && ![candidate isKindOfClass:[UICollectionView class]])
        candidate = candidate.superview;
    return (UICollectionView *)candidate;
}

id<UIContentConfiguration> charon_host_content(UIView *host)
{
    CharonHostState *state = charon_state(host, NO);
    return state ? [state->content copyWithZone:nil] : nil;
}

static void charon_install_content(UIView *host, CharonHostState *state, id<UIContentConfiguration> configuration)
{
    state->content = [configuration copyWithZone:nil];
    UIView *container = charon_host_content_view(host);
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

void charon_host_set_content(UIView *host, id<UIContentConfiguration> configuration)
{
    charon_install_content(host, charon_state(host, YES), configuration);
}

UIBackgroundConfiguration *charon_host_background(UIView *host)
{
    CharonHostState *state = charon_state(host, NO);
    return state ? [state->background copy] : nil;
}

static void charon_restore_backgrounds(UIView *host, CharonHostState *state)
{
    for (UIView *view in state->hidden)
        view.hidden = NO;
    state->hidden = nil;
    if (state->savedStyle && [host isKindOfClass:[UITableViewCell class]])
        ((UITableViewCell *)host).selectionStyle = (UITableViewCellSelectionStyle)state->selectionStyle;
    state->savedStyle = NO;
}

static void charon_install_background(UIView *host, CharonHostState *state, UIBackgroundConfiguration *configuration)
{
    state->background = [configuration copy];
    if (!configuration) {
        [state->backgroundView removeFromSuperview];
        state->backgroundView = nil;
        charon_restore_backgrounds(host, state);
        return;
    }
    if (!state->backgroundView) {
        state->backgroundView = [[CharonBackgroundView alloc] init];
        UIView *container = charon_host_content_view(host);
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
    [state->backgroundView charon_applyConfiguration:configuration inBounds:host.bounds tint:host.tintColor];
}

void charon_host_set_background(UIView *host, UIBackgroundConfiguration *configuration)
{
    charon_install_background(host, charon_state(host, YES), configuration);
}

BOOL charon_host_automatic(UIView *host, BOOL background)
{
    CharonHostState *state = charon_state(host, NO);
    return !state || !(background ? state->manualBackground : state->manualContent);
}

void charon_host_set_automatic(UIView *host, BOOL background, BOOL automatic)
{
    CharonHostState *state = charon_state(host, YES);
    if (background)
        state->manualBackground = !automatic;
    else
        state->manualContent = !automatic;
}

void charon_host_default_update(UIView *host, UIViewConfigurationState *viewState)
{
    CharonHostState *state = charon_state(host, YES);
    if (!state->manualContent && state->content)
        charon_install_content(host, state, [state->content updatedConfigurationForState:viewState]);
    if (!state->manualBackground && state->background)
        charon_install_background(host, state, [state->background updatedConfigurationForState:viewState]);
}

NSNumber *charon_host_table_style(UITableViewCell *cell)
{
    return objc_getAssociatedObject(cell, &CharonTableStyleKey);
}

@implementation UIView (CharonListHost)

- (UIView *)charon_configurationContainer
{
    return charon_host_content_view(self);
}

- (UIViewConfigurationState *)charon_makeConfigurationState
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
        [(UICellConfigurationState *)state setEditing:[charon_owning_collection_view(self) charon_editing]];
        if ([self respondsToSelector:@selector(charon_isExpanded)])
            [(UICellConfigurationState *)state setExpanded:[(UICollectionViewListCell *)self charon_isExpanded]];
    } else if ([self isKindOfClass:[UITableViewCell class]]) {
        UITableViewCell *cell = (UITableViewCell *)self;
        state.selected = cell.selected;
        state.highlighted = cell.highlighted;
        [(UICellConfigurationState *)state setEditing:[[cell valueForKey:@"editing"] boolValue]];
    }
    return state;
}

- (void)charon_setNeedsUpdateConfiguration
{
    charon_state(self, YES)->needsUpdate = YES;
    [self setNeedsLayout];
}

- (void)charon_layoutWillRun
{
    CharonHostState *state = charon_state(self, YES);
    if (!state->needsUpdate || state->updating)
        return;
    state->needsUpdate = NO;
    state->updating = YES;
    UIViewConfigurationState *configurationState = [self charon_makeConfigurationState];
    ((void (*)(id, SEL, id))objc_msgSend)(self, @selector(updateConfigurationUsingState:), configurationState);
    // The handler of iOS 15 runs after the view's own update, with the same state.
    void (^handler)(id, id) = objc_getAssociatedObject(self, &CharonUpdateHandlerKey);
    if (handler)
        handler(self, configurationState);
    state->updating = NO;
}

- (void)charon_layoutDidRun
{
    CharonHostState *state = charon_state(self, NO);
    if (!state)
        return;
    if (state->backgroundView)
        [state->backgroundView charon_applyConfiguration:state->background inBounds:self.bounds tint:self.tintColor];
    if (state->contentView && state->contentView.superview == charon_host_content_view(self))
        state->contentView.frame = charon_host_content_view(self).bounds;
}

@end

void charon_request_update(UIView *view)
{
    ((void (*)(id, SEL))objc_msgSend)(view, @selector(setNeedsUpdateConfiguration));
}

id charon_host_update_handler(UIView *host)
{
    return objc_getAssociatedObject(host, &CharonUpdateHandlerKey);
}

void charon_host_set_update_handler(UIView *host, id handler)
{
    objc_setAssociatedObject(host, &CharonUpdateHandlerKey, [handler copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    charon_request_update(host);
}

static void charon_wrap(Class cls, SEL selector, id (^make)(IMP original))
{
    Method method = class_getInstanceMethod(cls, selector);
    if (!method)
        return;
    IMP original = method_getImplementation(method);
    class_replaceMethod(cls, selector, imp_implementationWithBlock(make(original)), method_getTypeEncoding(method));
}

@interface CharonConfigurationHooks : NSObject
@end

@implementation CharonConfigurationHooks

+ (void)load
{
    Class collection = [UICollectionViewCell class], table = [UITableViewCell class], header = [UITableViewHeaderFooterView class];
    charon_wrap(collection, @selector(setSelected:), ^id(IMP original) {
        return ^(UICollectionViewCell *self_, BOOL value) {
            ((void (*)(id, SEL, BOOL))original)(self_, @selector(setSelected:), value);
            charon_request_update(self_);
        };
    });
    charon_wrap(collection, @selector(setHighlighted:), ^id(IMP original) {
        return ^(UICollectionViewCell *self_, BOOL value) {
            ((void (*)(id, SEL, BOOL))original)(self_, @selector(setHighlighted:), value);
            charon_request_update(self_);
        };
    });
    charon_wrap(table, @selector(setSelected:animated:), ^id(IMP original) {
        return ^(UITableViewCell *self_, BOOL value, BOOL animated) {
            ((void (*)(id, SEL, BOOL, BOOL))original)(self_, @selector(setSelected:animated:), value, animated);
            charon_request_update(self_);
        };
    });
    charon_wrap(table, @selector(setHighlighted:animated:), ^id(IMP original) {
        return ^(UITableViewCell *self_, BOOL value, BOOL animated) {
            ((void (*)(id, SEL, BOOL, BOOL))original)(self_, @selector(setHighlighted:animated:), value, animated);
            charon_request_update(self_);
        };
    });
    charon_wrap(table, NSSelectorFromString(@"setEditing:animated:"), ^id(IMP original) {
        return ^(UITableViewCell *self_, BOOL value, BOOL animated) {
            ((void (*)(id, SEL, BOOL, BOOL))original)(self_, NSSelectorFromString(@"setEditing:animated:"), value, animated);
            charon_request_update(self_);
        };
    });
    charon_wrap(table, @selector(initWithStyle:reuseIdentifier:), ^id(IMP original) {
        return ^(UITableViewCell *self_, UITableViewCellStyle style, NSString *identifier) {
            UITableViewCell *cell = ((id (*)(id, SEL, UITableViewCellStyle, NSString *))original)(self_, @selector(initWithStyle:reuseIdentifier:), style, identifier);
            objc_setAssociatedObject(cell, &CharonTableStyleKey, @(style), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return cell;
        };
    });
    for (Class cls in @[table, header]) {
        for (NSString *name in @[@"textLabel", @"detailTextLabel", @"imageView"]) {
            SEL selector = NSSelectorFromString(name);
            if (cls == header && [name isEqual:@"imageView"])
                continue;
            charon_wrap(cls, selector, ^id(IMP original) {
                return ^id(UIView *self_) {
                    return charon_host_content(self_) ? nil : ((id (*)(id, SEL))original)(self_, selector);
                };
            });
        }
    }
    for (Class cls in @[collection, table, header]) {
        charon_wrap(cls, @selector(layoutSubviews), ^id(IMP original) {
            return ^(UIView *self_) {
                [self_ charon_layoutWillRun];
                ((void (*)(id, SEL))original)(self_, @selector(layoutSubviews));
                [self_ charon_layoutDidRun];
            };
        });
    }
}

@end
