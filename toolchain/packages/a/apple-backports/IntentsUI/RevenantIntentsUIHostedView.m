#import <Intents/Intents.h>
#import <IntentsUI/IntentsUI.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface CharonIntentsUIHostedViewController : UIViewController <INUIHostedViewControlling>

- (instancetype)initWithInteraction:(INInteraction *)interaction;

@property (nonatomic, readonly, strong) INInteraction *interaction;
@property (nonatomic, readonly) INUIHostedViewContext hostedViewContext;
@property (nonatomic, readonly) INUIInteractiveBehavior interactiveBehavior;

@end

@implementation CharonIntentsUIHostedViewController {
    NSMutableDictionary *_labelsByParameter;
    UIButton *_behaviorButton;
    NSMutableSet *_configured;
}

@synthesize interaction = _interaction;
@synthesize hostedViewContext = _hostedViewContext;
@synthesize interactiveBehavior = _interactiveBehavior;

- (instancetype)initWithInteraction:(INInteraction *)interaction
{
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _interaction = interaction;
        _labelsByParameter = [NSMutableDictionary dictionary];
        _configured = [NSMutableSet set];
        self.view.backgroundColor = [UIColor clearColor];
    }
    return self;
}

#pragma mark - INUIHostedViewControlling

- (void)configureWithInteraction:(INInteraction *)interaction
                         context:(INUIHostedViewContext)context
                      completion:(void (^)(CGSize desiredSize))completion
{
    _interaction = interaction;
    _hostedViewContext = context;
    NSArray<INParameter *> *parameters = [self charon_parametersOfInteraction:interaction];
    NSSet *wanted = [NSSet setWithArray:parameters];
    [self charon_applyParameters:wanted];
    [self charon_applyContext:context];
    if (completion) {
        completion([self charon_desiredSize]);
    }
}

- (void)configureViewForParameters:(NSSet<INParameter *> *)parameters
                     ofInteraction:(INInteraction *)interaction
                interactiveBehavior:(INUIInteractiveBehavior)interactiveBehavior
                            context:(INUIHostedViewContext)context
                        completion:(void (^)(BOOL success, NSSet<INParameter *> *configuredParameters,
                                            CGSize desiredSize))completion
{
    _interaction = interaction;
    _hostedViewContext = context;
    _interactiveBehavior = interactiveBehavior;
    NSSet *carried = [NSSet setWithArray:[self charon_parametersOfInteraction:interaction]];
    NSMutableSet *applicable = [NSMutableSet set];
    for (INParameter *parameter in parameters) {
        if ([carried containsObject:parameter]) {
            [applicable addObject:parameter];
        }
    }
    [self charon_applyParameters:applicable];
    [self charon_applyBehavior:interactiveBehavior];
    [self charon_applyContext:context];
    if (completion) {
        completion(YES, [NSSet setWithSet:_configured], [self charon_desiredSize]);
    }
}

#pragma mark - What the view does with them

- (NSArray<INParameter *> *)charon_parametersOfInteraction:(INInteraction *)interaction
{
    INIntent *intent = interaction.intent;
    if (!intent) {
        return [NSArray array];
    }
    unsigned count = 0;
    Ivar *ivars = class_copyIvarList([intent class], &count);
    NSMutableArray *parameters = [NSMutableArray arrayWithCapacity:count];
    for (unsigned index = 0; index < count; index++) {
        const char *name = ivar_getName(ivars[index]);
        if (!name || name[0] != '_') {
            continue;
        }
        [parameters addObject:[INParameter parameterForClass:[intent class]
                                                     keyPath:[NSString stringWithUTF8String:name + 1]]];
    }
    free(ivars);
    return parameters;
}

- (void)charon_applyParameters:(NSSet *)parameters
{
    for (INParameter *parameter in parameters) {
        NSString *key = parameter.parameterKeyPath;
        id value = [_interaction parameterValueForParameter:parameter];
        if (!key) {
            continue;
        }
        if (!value) {
            [_configured removeObject:parameter];
            continue;
        }
        UILabel *label = _labelsByParameter[key];
        if (!label) {
            label = [[UILabel alloc] initWithFrame:CGRectZero];
            label.numberOfLines = 0;
            [self.view addSubview:label];
            _labelsByParameter[key] = label;
        }
        label.text = [NSString stringWithFormat:@"%@: %@", key, value];
        [_configured addObject:parameter];
    }
}

- (void)charon_applyContext:(INUIHostedViewContext)context
{
    self.view.hidden = context == INUIHostedViewContextSiriSnippet && _labelsByParameter.count == 0;
}

- (void)charon_applyBehavior:(INUIInteractiveBehavior)behavior
{
    [_behaviorButton removeFromSuperview];
    _behaviorButton = nil;
    switch (behavior) {
        case INUIInteractiveBehaviorNextView: {
            _behaviorButton = [self charon_buttonWithTitle:@"›" action:@selector(charon_next:)];
            break;
        }
        case INUIInteractiveBehaviorLaunch: {
            _behaviorButton = [self charon_buttonWithTitle:@"Open" action:@selector(charon_launch:)];
            break;
        }
        case INUIInteractiveBehaviorGenericAction: {
            _behaviorButton = [self charon_buttonWithTitle:@"Do it" action:@selector(charon_act:)];
            _behaviorButton.titleLabel.font = [UIFont boldSystemFontOfSize:22.0f];
            break;
        }
        case INUIInteractiveBehaviorNone:
        default:
            break;
    }
    if (_behaviorButton) {
        [self.view addSubview:_behaviorButton];
    }
    [self.view setNeedsLayout];
}

- (UIButton *)charon_buttonWithTitle:(NSString *)title action:(SEL)action
{
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)charon_next:(id)sender { }
- (void)charon_launch:(id)sender { }
- (void)charon_act:(id)sender { }

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    CGFloat inset = 12.0f;
    CGFloat y = inset;
    CGFloat width = CGRectGetWidth(self.view.bounds) - 2 * inset;
    for (NSString *key in [_labelsByParameter.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        UILabel *label = _labelsByParameter[key];
        CGSize fitted = [label sizeThatFits:CGSizeMake(width, CGFLOAT_MAX)];
        label.frame = CGRectMake(inset, y, width, fitted.height);
        y += fitted.height + 4.0f;
    }
    if (_behaviorButton) {
        _behaviorButton.frame = CGRectMake(inset, y, 120.0f, 44.0f);
    }
}

- (CGSize)charon_desiredSize
{
    CGSize fitted = [self.view sizeThatFits:CGSizeMake(CGRectGetWidth(self.view.bounds), CGFLOAT_MAX)];
    return CGSizeMake(CGRectGetWidth(self.view.bounds) > 0 ? CGRectGetWidth(self.view.bounds) : 320.0f,
                      fitted.height > 0 ? fitted.height : 44.0f);
}

@end
