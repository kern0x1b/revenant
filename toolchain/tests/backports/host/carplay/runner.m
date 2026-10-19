#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <CarPlay/CarPlay.h>

@interface revenantHost_CPVoiceControlTemplate (RevenantHarness)
- (UIViewController *)revenant_viewControllerForInterfaceController:(id)controller;
@end

@interface revenantHost_CPTrip (RevenantHarness)
- (instancetype)initRevenantTrip;
@end

@interface revenantHost_CPManeuver (RevenantHarness)
- (instancetype)initRevenantManeuver;
@end

@interface revenantHost_CPMapTemplate (RevenantHarness)
- (id)revenant_navigationSession;
- (void)revenant_setNavigationSession:(id)session;
- (UIView *)revenant_mapView;
- (void)revenant_setMapView:(UIView *)view;
@end

@interface revenantHost_CPTravelEstimates (RevenantHarness)
- (instancetype)initRevenantWithTimeRemaining:(NSTimeInterval)time;
@end

@interface revenantHost_CPLane (RevenantHarness)
- (instancetype)init;
@end

@interface revenantHost_CPLaneGuidance (RevenantHarness)
- (instancetype)init;
@end

@interface revenantHost_CPSessionConfiguration (RevenantHarness)
- (instancetype)initWithDelegate:(id)delegate;
@end

@protocol revenantHost_CPSessionConfigurationDelegate <NSObject>
@optional
- (void)sessionConfiguration:(id)sessionConfiguration
    limitedUserInterfacesChanged:(NSUInteger)limitedUserInterfaces;
- (void)sessionConfiguration:(id)sessionConfiguration contentStyleChanged:(NSUInteger)contentStyle;
@end

@interface revenantHost_TestSessionConfigurationDelegate : NSObject <revenantHost_CPSessionConfigurationDelegate>
@end

@implementation revenantHost_TestSessionConfigurationDelegate
@end

static int gChecks = 0;
static int gFailures = 0;
static NSMutableArray *gAnswers = nil;

static void answer(NSString *label, NSString *detail)
{
    if (gAnswers != nil) {
        [gAnswers addObject:[NSString stringWithFormat:@"%@\t%@", label, detail]];
    }
}

static void check(NSString *what, BOOL ok, NSString *detail)
{
    gChecks++;
    if (!ok) {
        gFailures++;
    }
    printf("%-4s %-58s %s\n", ok ? "ok" : "FAIL", what.UTF8String, detail.UTF8String);
    answer(what, detail);
}

static NSString *describe(id object)
{
    if (object == nil) {
        return @"nil";
    }
    if ([object isKindOfClass:[NSArray class]]) {
        return [NSString stringWithFormat:@"array of %lu", (unsigned long)[(NSArray *)object count]];
    }
    if ([object isKindOfClass:[NSString class]]) {
        return [NSString stringWithFormat:@"string %@", object];
    }
    if ([object isKindOfClass:[NSNumber class]]) {
        return [NSString stringWithFormat:@"number %@", object];
    }
    return [NSString stringWithFormat:@"%@", NSStringFromClass([object class])];
}

static SEL registeredAction(UIControl *control, id target)
{
    if (control == nil || target == nil) {
        return NULL;
    }
    NSArray *registered = [control actionsForTarget:target forControlEvent:UIControlEventTouchUpInside];
    id first = registered.firstObject;
    if ([first isKindOfClass:[NSInvocation class]]) {
        return [(NSInvocation *)first selector];
    }
    if ([first isKindOfClass:[NSString class]]) {
        return NSSelectorFromString((NSString *)first);
    }
    return NULL;
}

static UILabel *currentCardLabel(UIView *canvas)
{
    UIView *card = canvas.subviews.lastObject;
    for (UIView *inner in card.subviews) {
        if ([inner isKindOfClass:[UILabel class]]) {
            return (UILabel *)inner;
        }
    }
    return nil;
}

static NSString *guidanceText(UIView *canvas)
{
    UILabel *label = currentCardLabel(canvas);
    return label != nil ? label.text : nil;
}

int main(int argc, const char *argv[])
{
    @autoreleasepool {
        if (argc > 1) {
            gAnswers = [NSMutableArray array];
        }

        printf("# the port's own voice control, on this Mac, through the runtime\n");
        printf("# every name is revenantHost_-prefixed, so Apple's CarPlay is not reachable here\n\n");

        printf("== CPVoiceControlState ==\n");
        revenantHost_CPVoiceControlState *state = [[revenantHost_CPVoiceControlState alloc]
            initWithIdentifier:@"revenant.listening"
                  titleVariants:@[@"Listening", @"Listen"]
                          image:nil
                        repeats:YES];
        check(@"identifier answers what the initialiser was given",
              [state.identifier isEqualToString:@"revenant.listening"], describe(state.identifier));
        check(@"titleVariants answers the array it was given", state.titleVariants.count == 2,
              describe(state.titleVariants));
        check(@"repeats answers YES", state.repeats == YES,
              [NSString stringWithFormat:@"%d", (int)state.repeats]);
        check(@"image answers nil when none was given", state.image == nil, describe(state.image));
        check(@"+supportsSecureCoding is YES (NSSecureCoding is in the header)",
              [revenantHost_CPVoiceControlState supportsSecureCoding] ? @"YES" : @"NO",
              [revenantHost_CPVoiceControlState supportsSecureCoding] ? @"YES" : @"NO");

        revenantHost_CPVoiceControlState *bare = [[revenantHost_CPVoiceControlState alloc]
            initWithIdentifier:@"revenant.bare" titleVariants:nil image:nil repeats:NO];
        check(@"titleVariants answers nil when it was given nil", bare.titleVariants == nil,
              describe(bare.titleVariants));

        UIGraphicsBeginImageContextWithOptions(CGSizeMake(300.0, 300.0), NO, 1.0);
        [[UIColor redColor] setFill];
        UIRectFill(CGRectMake(0.0, 0.0, 300.0, 300.0));
        UIImage *large = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        revenantHost_CPVoiceControlState *scaled = [[revenantHost_CPVoiceControlState alloc]
            initWithIdentifier:@"revenant.scaled" titleVariants:@[@"Scaled"] image:large repeats:NO];
        check(@"an image over 150 points a side comes back 150 by 150",
              scaled.image != nil && scaled.image.size.width <= 150.0 && scaled.image.size.height <= 150.0,
              [NSString stringWithFormat:@"%g by %g", scaled.image.size.width, scaled.image.size.height]);

        NSError *error = nil;
        NSData *coded = [NSKeyedArchiver archivedDataWithRootObject:state requiringSecureCoding:YES
                                                                error:&error];
        revenantHost_CPVoiceControlState *back = coded == nil ? nil
            : [NSKeyedUnarchiver unarchivedObjectOfClasses:
                   [NSSet setWithObjects:[revenantHost_CPVoiceControlState class], [NSString class],
                                         [NSArray class], [UIImage class], nil]
                                              fromData:coded
                                                 error:&error];
        check(@"a state survives an NSSecureCoding round trip with its identifier",
              back != nil && [back.identifier isEqualToString:@"revenant.listening"],
              back ? describe(back.identifier) : [NSString stringWithFormat:@"nil (%@)",
                                                    error.localizedDescription ?: @"no error"]);

        printf("\n== CPVoiceControlTemplate ==\n");
        NSMutableArray *states = [NSMutableArray array];
        for (int i = 0; i < 6; i++) {
            [states addObject:[[revenantHost_CPVoiceControlState alloc]
                initWithIdentifier:[NSString stringWithFormat:@"revenant.state%d", i]
                      titleVariants:@[[NSString stringWithFormat:@"State %d", i]]
                              image:nil
                            repeats:NO]];
        }
        revenantHost_CPVoiceControlTemplate *voice =
            [[revenantHost_CPVoiceControlTemplate alloc] initWithVoiceControlStates:states];
        check(@"the template keeps the five states the header's limit allows",
              voice.voiceControlStates.count == 5,
              [NSString stringWithFormat:@"%lu of %lu", (unsigned long)voice.voiceControlStates.count,
                  (unsigned long)states.count]);
        check(@"the first of the states it was given is the active one",
              [voice.activeStateIdentifier isEqualToString:@"revenant.state0"],
              describe(voice.activeStateIdentifier));

        [voice activateVoiceControlStateWithIdentifier:@"revenant.state3"];
        check(@"activating switches the active state with no car attached (measured)",
              [voice.activeStateIdentifier isEqualToString:@"revenant.state3"],
              [NSString stringWithFormat:@"active is now %@", describe(voice.activeStateIdentifier)]);

        [voice activateVoiceControlStateWithIdentifier:@"revenant.state99"];
        check(@"an identifier no state carries becomes the active one anyway (measured)",
              [voice.activeStateIdentifier isEqualToString:@"revenant.state99"],
              [NSString stringWithFormat:@"active is now %@", describe(voice.activeStateIdentifier)]);

        NSUInteger effective = 0;
        const NSUInteger rounds = 12;
        for (NSUInteger round = 0; round < rounds; round++) {
            NSString *wanted = [NSString stringWithFormat:@"revenant.state%lu", (unsigned long)(round % 5)];
            [voice activateVoiceControlStateWithIdentifier:wanted];
            if ([voice.activeStateIdentifier isEqualToString:wanted]) {
                effective++;
            }
        }
        check(@"twelve activations in a tight loop all take effect: no interval in the object",
              effective == rounds,
              [NSString stringWithFormat:@"%lu of %lu", (unsigned long)effective, (unsigned long)rounds]);

        revenantHost_CPVoiceControlTemplate *empty =
            [[revenantHost_CPVoiceControlTemplate alloc] initWithVoiceControlStates:@[]];
        check(@"an empty array of states keeps an empty array and no active state",
              empty.voiceControlStates.count == 0 && empty.activeStateIdentifier == nil,
              [NSString stringWithFormat:@"%lu states, active %@", (unsigned long)empty.voiceControlStates.count,
                  describe(empty.activeStateIdentifier)]);
        revenantHost_CPVoiceControlTemplate *none =
            [[revenantHost_CPVoiceControlTemplate alloc] initWithVoiceControlStates:nil];
        check(@"a nil array of states answers nil for both, as the framework does",
              none.voiceControlStates == nil && none.activeStateIdentifier == nil,
              [NSString stringWithFormat:@"states %@, active %@", describe(none.voiceControlStates),
                  describe(none.activeStateIdentifier)]);

        printf("\n== the template's own view ==\n");
        UIViewController *view = [voice revenant_viewControllerForInterfaceController:nil];
        view.view.frame = CGRectMake(0.0, 0.0, 800.0, 480.0);
        [view.view setNeedsLayout];
        [view.view layoutIfNeeded];
        UILabel *title = nil;
        NSMutableArray *plates = [NSMutableArray array];
        for (UIView *sub in view.view.subviews) {
            if ([sub isKindOfClass:[UILabel class]]) {
                title = (UILabel *)sub;
            } else if ([sub isKindOfClass:[UIButton class]]) {
                [plates addObject:sub];
            }
        }
        check(@"the pushed view draws the active state's own title",
              title != nil && [title.text isEqualToString:@"State 1"],
              title != nil ? describe(title.text) : @"no label");
        check(@"the pushed view draws one plate per state the template kept",
              plates.count == 5,
              [NSString stringWithFormat:@"%lu plates", (unsigned long)plates.count]);
        UIButton *plate = plates.count == 5 ? (UIButton *)plates[4] : nil;
        id target = plate.allTargets.anyObject;
        SEL action = registeredAction(plate, target);
        check(@"every plate has a target and an action registered for a touch",
              plate != nil && target != nil && action != NULL && [target respondsToSelector:action],
              [NSString stringWithFormat:@"target %@ action %@",
                  target ? NSStringFromClass([target class]) : @"none",
                  action ? NSStringFromSelector(action) : @"none"]);
        if (target != nil && action != NULL) {
            ((void (*)(id, SEL, id))objc_msgSend)(target, action, plate);
        }
        check(@"tapping a plate switches the state to the one that plate names",
              [voice.activeStateIdentifier isEqualToString:@"revenant.state4"],
              [NSString stringWithFormat:@"active is now %@", describe(voice.activeStateIdentifier)]);
        revenantHost_CPVoiceControlState *twoVariants = [[revenantHost_CPVoiceControlState alloc]
            initWithIdentifier:@"revenant.two"
              titleVariants:@[@"Listening to the voice control of the car", @"Listen"]
                      image:nil
                    repeats:NO];
        revenantHost_CPVoiceControlTemplate *narrow =
            [[revenantHost_CPVoiceControlTemplate alloc] initWithVoiceControlStates:@[twoVariants]];
        UIViewController *narrowView = [narrow revenant_viewControllerForInterfaceController:nil];
        narrowView.view.frame = CGRectMake(0.0, 0.0, 220.0, 480.0);
        [narrowView.view setNeedsLayout];
        [narrowView.view layoutIfNeeded];
        for (UIView *sub in narrowView.view.subviews) {
            if ([sub isKindOfClass:[UILabel class]] && [(UILabel *)sub text].length > 0) {
                check(@"a title variant too long for the template falls back to one that fits",
                      [(UILabel *)sub text].length < @"Listening to the voice control of the car".length,
                      describe([(UILabel *)sub text]));
                break;
            }
        }

        printf("\n== the navigation session, begun by the map template ==\n");
        revenantHost_CPMapTemplate *map = [[revenantHost_CPMapTemplate alloc] init];
        UIView *canvas = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, 800.0, 480.0)];
        [map revenant_setMapView:canvas];
        revenantHost_CPTrip *trip = [[revenantHost_CPTrip alloc] initRevenantTrip];
        revenantHost_CPNavigationSession *session = [map startNavigationSessionForTrip:trip];
        check(@"the map template's own method hands back a session", session != nil,
              session ? describe(session) : @"nil");
        check(@"the session answers the trip it was begun for", session.trip == trip,
              describe(session.trip));
        check(@"a second call for the same trip hands back the session already running",
              [map startNavigationSessionForTrip:trip] == session,
              describe([map startNavigationSessionForTrip:trip]));

        revenantHost_CPManeuver *next = [[revenantHost_CPManeuver alloc] initRevenantManeuver];
        session.upcomingManeuvers = @[next];
        check(@"the session keeps the maneuvers a program set", session.upcomingManeuvers.count == 1,
              describe(session.upcomingManeuvers));
        revenantHost_CPTravelEstimates *estimates =
            [[revenantHost_CPTravelEstimates alloc] initRevenantWithTimeRemaining:125.0];
        [session updateTravelEstimates:estimates forManeuver:next];
        check(@"the estimates land in the map template's own guidance card",
              [guidanceText(canvas) isEqualToString:@"2 min 05 sec"], describe(guidanceText(canvas)));

        revenantHost_CPTravelEstimates *unknown =
            [[revenantHost_CPTravelEstimates alloc] initRevenantWithTimeRemaining:-1.0];
        [session updateTravelEstimates:unknown forManeuver:next];
        check(@"a negative time remaining renders as the header's own \"--\"",
              [guidanceText(canvas) isEqualToString:@"--"], describe(guidanceText(canvas)));

        [session pauseTripForReason:1 description:@"Loading route"];
        check(@"a pause with the header's own reason shows its description",
              [guidanceText(canvas) isEqualToString:@"Loading route"], describe(guidanceText(canvas)));
        [session pauseTripForReason:1 description:nil];
        check(@"a pause with no description says so rather than nothing",
              [guidanceText(canvas) isEqualToString:@"Trip paused"], describe(guidanceText(canvas)));

        UIColor *turnCard = [UIColor blueColor];
        [session pauseTripForReason:1 description:@"Rerouting" turnCardColor:turnCard];
        UIView *drawn = canvas.subviews.lastObject;
        check(@"a turn card colour is the card's colour, the header's first choice",
              drawn != nil && [drawn.backgroundColor isEqual:turnCard],
              drawn != nil ? @"blue" : @"no card");
        map.guidanceBackgroundColor = [UIColor greenColor];
        [session pauseTripForReason:1 description:@"Rerouting" turnCardColor:nil];
        drawn = canvas.subviews.lastObject;
        check(@"with no turn card colour the card falls back to the template's guidanceBackgroundColor",
              drawn != nil && [drawn.backgroundColor isEqual:[UIColor greenColor]],
              drawn != nil ? @"green" : @"no card");

        [session finishTrip];
        check(@"a finished trip says so", [guidanceText(canvas) isEqualToString:@"Trip finished"],
              describe(guidanceText(canvas)));
        [session cancelTrip];
        check(@"a cancelled trip says so", [guidanceText(canvas) isEqualToString:@"Trip cancelled"],
              describe(guidanceText(canvas)));

        revenantHost_CPMapTemplate *unpushed = [[revenantHost_CPMapTemplate alloc] init];
        revenantHost_CPNavigationSession *pending = [unpushed startNavigationSessionForTrip:trip];
        [pending updateTravelEstimates:estimates forManeuver:next];
        check(@"guidance asked for before the template is pushed draws nothing and loses nothing",
              pending != nil && unpushed.revenant_mapView == nil,
              describe(pending));

        printf("\n== the 17.4 members, on a session the program holds ==\n");
        {
            revenantHost_CPMapTemplate *laneMap = [[revenantHost_CPMapTemplate alloc] init];
            UIView *laneCanvas = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, 800.0, 480.0)];
            [laneMap revenant_setMapView:laneCanvas];
            revenantHost_CPNavigationSession *held =
                [laneMap startNavigationSessionForTrip:[[revenantHost_CPTrip alloc] initRevenantTrip]];

            check(@"the port's own upcomingManeuvers with nothing set is an empty array",
                  held.upcomingManeuvers != nil && held.upcomingManeuvers.count == 0,
                  describe(held.upcomingManeuvers));
            check(@"currentRoadNameVariants answers nil before anything is set",
                  held.currentRoadNameVariants == nil, describe(held.currentRoadNameVariants));
            check(@"currentLaneGuidance answers nil before anything is set",
                  held.currentLaneGuidance == nil, describe(held.currentLaneGuidance));
            check(@"maneuverState answers 0 before anything is set",
                  held.maneuverState == 0, [NSString stringWithFormat:@"%lu", (unsigned long)held.maneuverState]);
            check(@"CPLaneGuidance is the class currentLaneGuidance's value is",
                  NSClassFromString(@"revenantHost_CPLaneGuidance") != nil, @"present");
            check(@"CPRouteInformation is the class resumeTrip takes",
                  NSClassFromString(@"revenantHost_CPRouteInformation") != nil, @"present");

            revenantHost_CPLaneGuidance *guidance = [[revenantHost_CPLaneGuidance alloc] init];
            check(@"a fresh lane guidance's lanes answer nil, not an empty array (measured)",
                  guidance.lanes == nil, describe(guidance.lanes));
            check(@"a fresh lane guidance's instructionVariants answer nil, not an empty array (measured)",
                  guidance.instructionVariants == nil, describe(guidance.instructionVariants));
            check(@"+supportsSecureCoding is YES (NSSecureCoding is in the header, CPLaneGuidance.h:17)",
                  [revenantHost_CPLaneGuidance supportsSecureCoding] ? @"YES" : @"NO",
                  [revenantHost_CPLaneGuidance supportsSecureCoding] ? @"YES" : @"NO");

            revenantHost_CPRouteInformation *route =
                [[revenantHost_CPRouteInformation alloc] initWithManeuvers:nil laneGuidances:nil
                                                        currentManeuvers:nil currentLaneGuidance:nil
                                                  tripTravelEstimates:nil maneuverTravelEstimates:nil];
            check(@"route information from nil in every slot: maneuvers answers nil",
                  route.maneuvers == nil, describe(route.maneuvers));
            check(@"route information from nil in every slot: laneGuidances answers nil",
                  route.laneGuidances == nil, describe(route.laneGuidances));
            check(@"route information from nil in every slot: currentManeuvers answers nil",
                  route.currentManeuvers == nil, describe(route.currentManeuvers));
            check(@"route information from nil in every slot: currentLaneGuidance answers nil",
                  route.currentLaneGuidance == nil, describe(route.currentLaneGuidance));
            check(@"route information from nil in every slot: tripTravelEstimates answers nil",
                  route.tripTravelEstimates == nil, describe(route.tripTravelEstimates));
            check(@"route information from nil in every slot: maneuverTravelEstimates answers nil",
                  route.maneuverTravelEstimates == nil, describe(route.maneuverTravelEstimates));
        }

        printf("\n== the session configuration, with no head unit ==\n");
        {
            revenantHost_CPSessionConfiguration *configuration =
                [[revenantHost_CPSessionConfiguration alloc] initWithDelegate:nil];
            check(@"the designated initialiser makes a configuration", configuration != nil,
                  @"a configuration");
            check(@"delegate answers the delegate it was given (nil here)", configuration.delegate == nil,
                  describe(configuration.delegate));
            check(@"limitedUserInterfaces answers the mask the connected system suggests",
                  configuration.limitedUserInterfaces == 0,
                  [NSString stringWithFormat:@"%lu",
                      (unsigned long)configuration.limitedUserInterfaces]);
            check(@"contentStyle answers the style the connected system suggests",
                  configuration.contentStyle == 0,
                  [NSString stringWithFormat:@"%lu", (unsigned long)configuration.contentStyle]);

            check(@"the two values have no public setter: both are readonly in the header",
                  ![configuration respondsToSelector:@selector(setContentStyle:)]
                      && ![configuration respondsToSelector:@selector(setLimitedUserInterfaces:)],
                  @"neither setter is answered");

            revenantHost_TestSessionConfigurationDelegate *delegate =
                [[revenantHost_TestSessionConfigurationDelegate alloc] init];
            configuration.delegate = delegate;
            check(@"the delegate answers the delegate a caller set", configuration.delegate == delegate,
                  describe(configuration.delegate));
            __weak revenantHost_TestSessionConfigurationDelegate *weakDelegate = configuration.delegate;
            (void)weakDelegate;
        }

        printf("\nchecks=%d failures=%d\n", gChecks, gFailures);
        if (gAnswers != nil) {
            NSString *text = [gAnswers componentsJoinedByString:@"\n"];
            [text writeToFile:[NSString stringWithUTF8String:argv[1]] atomically:YES
                 encoding:NSUTF8StringEncoding error:NULL];
        }
        return gFailures == 0 ? 0 : 1;
    }
}
