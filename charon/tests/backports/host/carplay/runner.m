// The port's own voice control, driven through the twelve rows the queue asks about, and printed in
// the same `label<TAB>detail` shape the host differential prints so the two can be diffed line by
// line.
//
// The port's classes are reached through the runtime under their renamed names (`charonHost_…`), so
// nothing here can reach Apple's CarPlay by accident and every answer below is the port's own. The
// expectations are NOT written from the header: each one is what Apple's own object answered on this
// machine with no head unit attached, and `run.sh` refuses the run unless the two transcripts agree
// on every label they both carry.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <CarPlay/CarPlay.h>

// The port's own classes, reached through their renamed names. CarPlay.h is imported with the same
// -D renames the port's sources are compiled with, so it DECLARES charonHost_CPVoiceControlState,
// charonHost_CPVoiceControlTemplate, charonHost_CPNavigationSession, charonHost_CPMapTemplate,
// charonHost_CPTrip, charonHost_CPManeuver and charonHost_CPTravelEstimates with the SDK's own
// signatures -- which is why nothing below redeclares them.
//
// What CarPlay.h does not declare, and what this file needs, are the port's own Charon members: the
// map template's three accessors for the session it stores and the map it draws over (the storage is
// the class's own, in CarPlayTemplatesView12.m, because a category cannot add an ivar), and the
// shim's own factory for an estimates object, which the SDK's property is readonly.

@interface charonHost_CPVoiceControlTemplate (CharonHarness)
- (UIViewController *)charon_viewControllerForInterfaceController:(id)controller;
@end

@interface charonHost_CPTrip (CharonHarness)
- (instancetype)initCharonTrip;
@end

@interface charonHost_CPManeuver (CharonHarness)
- (instancetype)initCharonManeuver;
@end

@interface charonHost_CPMapTemplate (CharonHarness)
- (id)charon_navigationSession;
- (void)charon_setNavigationSession:(id)session;
- (UIView *)charon_mapView;
- (void)charon_setMapView:(UIView *)view;
@end

@interface charonHost_CPTravelEstimates (CharonHarness)
- (instancetype)initCharonWithTimeRemaining:(NSTimeInterval)time;
@end

// The 17.4 classes are also renamed, and they have to be: the host probe asks Apple's own
// CPLaneGuidance and CPRouteInformation by name, and if the port's two answered to the same names in
// this image the comparison would be between an object and itself.
@interface charonHost_CPLane (CharonHarness)
- (instancetype)init;
@end

@interface charonHost_CPLaneGuidance (CharonHarness)
- (instancetype)init;
@end

// The session configuration is renamed for the same reason, and its delegate protocol with it: the host
// probe links Apple's own CarPlay, so a port class answering to Apple's name in this image would be the
// same object twice.
@interface charonHost_CPSessionConfiguration (CharonHarness)
- (instancetype)initWithDelegate:(id)delegate;
@end

@protocol charonHost_CPSessionConfigurationDelegate <NSObject>
@optional
- (void)sessionConfiguration:(id)sessionConfiguration
    limitedUserInterfacesChanged:(NSUInteger)limitedUserInterfaces;
- (void)sessionConfiguration:(id)sessionConfiguration contentStyleChanged:(NSUInteger)contentStyle;
@end

// A delegate to set, so the "the delegate answers the delegate a caller set" check has something to set.
// The protocol's methods are @optional, so a class that adopts it and implements neither is a delegate,
// which is what the header allows a caller to pass.
@interface charonHost_TestSessionConfigurationDelegate : NSObject <charonHost_CPSessionConfigurationDelegate>
@end

@implementation charonHost_TestSessionConfigurationDelegate
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

// Every check states the answer the PORT gave and whether it is the one Apple's gave; the labels are
// the host probe's labels verbatim, which is what makes the diff in run.sh a comparison of two
// measurements and not of two intentions.
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

// The action a control has registered for a target and an event, read back off the control. This SDK
// hands back one NSInvocation per pair whose selector is the action, and a string naming it on the
// Catalyst surface; both shapes are read, and NULL when the pair is not registered at all, which is
// what makes a plate with no action fail the check rather than pass it.
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

// The guidance the map template currently shows, read off its NEWEST card every time. The card is
// taken off the map and a new one put in its place on each update, so a label read once goes stale and
// a harness that held on to it would be reading a view the port had already removed.
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
        printf("# every name is charonHost_-prefixed, so Apple's CarPlay is not reachable here\n\n");

        // ---- the state, the six rows of CPVoiceControlState -------------------------------------
        printf("== CPVoiceControlState ==\n");
        charonHost_CPVoiceControlState *state = [[charonHost_CPVoiceControlState alloc]
            initWithIdentifier:@"charon.listening"
                  titleVariants:@[@"Listening", @"Listen"]
                          image:nil
                        repeats:YES];
        check(@"identifier answers what the initialiser was given",
              [state.identifier isEqualToString:@"charon.listening"], describe(state.identifier));
        check(@"titleVariants answers the array it was given", state.titleVariants.count == 2,
              describe(state.titleVariants));
        check(@"repeats answers YES", state.repeats == YES,
              [NSString stringWithFormat:@"%d", (int)state.repeats]);
        check(@"image answers nil when none was given", state.image == nil, describe(state.image));
        check(@"+supportsSecureCoding is YES (NSSecureCoding is in the header)",
              [charonHost_CPVoiceControlState supportsSecureCoding] ? @"YES" : @"NO",
              [charonHost_CPVoiceControlState supportsSecureCoding] ? @"YES" : @"NO");

        charonHost_CPVoiceControlState *bare = [[charonHost_CPVoiceControlState alloc]
            initWithIdentifier:@"charon.bare" titleVariants:nil image:nil repeats:NO];
        check(@"titleVariants answers nil when it was given nil", bare.titleVariants == nil,
              describe(bare.titleVariants));

        UIGraphicsBeginImageContextWithOptions(CGSizeMake(300.0, 300.0), NO, 1.0);
        [[UIColor redColor] setFill];
        UIRectFill(CGRectMake(0.0, 0.0, 300.0, 300.0));
        UIImage *large = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        charonHost_CPVoiceControlState *scaled = [[charonHost_CPVoiceControlState alloc]
            initWithIdentifier:@"charon.scaled" titleVariants:@[@"Scaled"] image:large repeats:NO];
        check(@"an image over 150 points a side comes back 150 by 150",
              scaled.image != nil && scaled.image.size.width <= 150.0 && scaled.image.size.height <= 150.0,
              [NSString stringWithFormat:@"%g by %g", scaled.image.size.width, scaled.image.size.height]);

        NSError *error = nil;
        NSData *coded = [NSKeyedArchiver archivedDataWithRootObject:state requiringSecureCoding:YES
                                                                error:&error];
        // The same allowed-class set the host probe uses, so the diff compares like with like: a
        // state holds an array of strings and an image, and a reader that does not allow them cannot
        // read it.
        charonHost_CPVoiceControlState *back = coded == nil ? nil
            : [NSKeyedUnarchiver unarchivedObjectOfClasses:
                   [NSSet setWithObjects:[charonHost_CPVoiceControlState class], [NSString class],
                                         [NSArray class], [UIImage class], nil]
                                              fromData:coded
                                                 error:&error];
        check(@"a state survives an NSSecureCoding round trip with its identifier",
              back != nil && [back.identifier isEqualToString:@"charon.listening"],
              back ? describe(back.identifier) : [NSString stringWithFormat:@"nil (%@)",
                                                    error.localizedDescription ?: @"no error"]);

        // ---- the template, the six rows of CPVoiceControlTemplate ---------------------------------
        printf("\n== CPVoiceControlTemplate ==\n");
        NSMutableArray *states = [NSMutableArray array];
        for (int i = 0; i < 6; i++) {
            [states addObject:[[charonHost_CPVoiceControlState alloc]
                initWithIdentifier:[NSString stringWithFormat:@"charon.state%d", i]
                      titleVariants:@[[NSString stringWithFormat:@"State %d", i]]
                              image:nil
                            repeats:NO]];
        }
        charonHost_CPVoiceControlTemplate *voice =
            [[charonHost_CPVoiceControlTemplate alloc] initWithVoiceControlStates:states];
        check(@"the template keeps the five states the header's limit allows",
              voice.voiceControlStates.count == 5,
              [NSString stringWithFormat:@"%lu of %lu", (unsigned long)voice.voiceControlStates.count,
                  (unsigned long)states.count]);
        check(@"the first of the states it was given is the active one",
              [voice.activeStateIdentifier isEqualToString:@"charon.state0"],
              describe(voice.activeStateIdentifier));

        [voice activateVoiceControlStateWithIdentifier:@"charon.state3"];
        check(@"activating switches the active state with no car attached (measured)",
              [voice.activeStateIdentifier isEqualToString:@"charon.state3"],
              [NSString stringWithFormat:@"active is now %@", describe(voice.activeStateIdentifier)]);

        [voice activateVoiceControlStateWithIdentifier:@"charon.state99"];
        check(@"an identifier no state carries becomes the active one anyway (measured)",
              [voice.activeStateIdentifier isEqualToString:@"charon.state99"],
              [NSString stringWithFormat:@"active is now %@", describe(voice.activeStateIdentifier)]);

        NSUInteger effective = 0;
        const NSUInteger rounds = 12;
        for (NSUInteger round = 0; round < rounds; round++) {
            NSString *wanted = [NSString stringWithFormat:@"charon.state%lu", (unsigned long)(round % 5)];
            [voice activateVoiceControlStateWithIdentifier:wanted];
            if ([voice.activeStateIdentifier isEqualToString:wanted]) {
                effective++;
            }
        }
        check(@"twelve activations in a tight loop all take effect: no interval in the object",
              effective == rounds,
              [NSString stringWithFormat:@"%lu of %lu", (unsigned long)effective, (unsigned long)rounds]);

        charonHost_CPVoiceControlTemplate *empty =
            [[charonHost_CPVoiceControlTemplate alloc] initWithVoiceControlStates:@[]];
        check(@"an empty array of states keeps an empty array and no active state",
              empty.voiceControlStates.count == 0 && empty.activeStateIdentifier == nil,
              [NSString stringWithFormat:@"%lu states, active %@", (unsigned long)empty.voiceControlStates.count,
                  describe(empty.activeStateIdentifier)]);
        charonHost_CPVoiceControlTemplate *none =
            [[charonHost_CPVoiceControlTemplate alloc] initWithVoiceControlStates:nil];
        check(@"a nil array of states answers nil for both, as the framework does",
              none.voiceControlStates == nil && none.activeStateIdentifier == nil,
              [NSString stringWithFormat:@"states %@, active %@", describe(none.voiceControlStates),
                  describe(none.activeStateIdentifier)]);

        // ---- and the drawing, which is what the template is for ----------------------------------
        // The template is a screen's contents, so it has to draw them: the view controller the
        // interface controller pushes is asked for here and must come back with the state's title
        // and one plate per state, and a tap on a plate has to switch the state.
        printf("\n== the template's own view ==\n");
        // Pushed the way the interface controller pushes it: the view is asked for, given the car's
        // own size, and laid out. Nothing here calls a draw method by hand.
        UIViewController *view = [voice charon_viewControllerForInterfaceController:nil];
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
        // The plate's own action, sent the way a touch sends it. UIControl's dispatch needs a window
        // and a Catalyst process has none, so the harness sends the action the plate REGISTERED to
        // the target it REGISTERED -- and the registration itself is read back, so a plate with no
        // target or no action is red here rather than passing by a direct call to the method.
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
              [voice.activeStateIdentifier isEqualToString:@"charon.state4"],
              [NSString stringWithFormat:@"active is now %@", describe(voice.activeStateIdentifier)]);
        // And the title the header's rule picks: the longest variant that fits. A template narrower
        // than the longest variant draws the shorter one rather than an empty label.
        charonHost_CPVoiceControlState *twoVariants = [[charonHost_CPVoiceControlState alloc]
            initWithIdentifier:@"charon.two"
              titleVariants:@[@"Listening to the voice control of the car", @"Listen"]
                      image:nil
                    repeats:NO];
        charonHost_CPVoiceControlTemplate *narrow =
            [[charonHost_CPVoiceControlTemplate alloc] initWithVoiceControlStates:@[twoVariants]];
        UIViewController *narrowView = [narrow charon_viewControllerForInterfaceController:nil];
        // Narrower than the long variant at the drawing size, which is what makes the header's rule
        // ("the longest variant that fits") choose the short one.
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

        // ---- the navigation session, the eight rows of CPNavigationSession ----------------------
        // The way in is the header's own: the map template's -startNavigationSessionForTrip:, which the
        // 26.2 header says is where a session comes to exist. There is no -init and no +new here and
        // there is none in the port: the header marks both NS_UNAVAILABLE.
        printf("\n== the navigation session, begun by the map template ==\n");
        charonHost_CPMapTemplate *map = [[charonHost_CPMapTemplate alloc] init];
        UIView *canvas = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, 800.0, 480.0)];
        [map charon_setMapView:canvas];
        charonHost_CPTrip *trip = [[charonHost_CPTrip alloc] initCharonTrip];
        charonHost_CPNavigationSession *session = [map startNavigationSessionForTrip:trip];
        check(@"the map template's own method hands back a session", session != nil,
              session ? describe(session) : @"nil");
        check(@"the session answers the trip it was begun for", session.trip == trip,
              describe(session.trip));
        check(@"a second call for the same trip hands back the session already running",
              [map startNavigationSessionForTrip:trip] == session,
              describe([map startNavigationSessionForTrip:trip]));

        charonHost_CPManeuver *next = [[charonHost_CPManeuver alloc] initCharonManeuver];
        session.upcomingManeuvers = @[next];
        check(@"the session keeps the maneuvers a program set", session.upcomingManeuvers.count == 1,
              describe(session.upcomingManeuvers));
        charonHost_CPTravelEstimates *estimates =
            [[charonHost_CPTravelEstimates alloc] initCharonWithTimeRemaining:125.0];
        [session updateTravelEstimates:estimates forManeuver:next];
        check(@"the estimates land in the map template's own guidance card",
              [guidanceText(canvas) isEqualToString:@"2 min 05 sec"], describe(guidanceText(canvas)));

        charonHost_CPTravelEstimates *unknown =
            [[charonHost_CPTravelEstimates alloc] initCharonWithTimeRemaining:-1.0];
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
        // The template's own colour first, because the card is drawn when the pause is recorded and not
        // when a property is set: the chain is read at the moment the guidance is drawn.
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

        // And the drawing is refused when the template has no map yet, which is the state a template is
        // in before an interface controller pushes it.
        charonHost_CPMapTemplate *unpushed = [[charonHost_CPMapTemplate alloc] init];
        charonHost_CPNavigationSession *pending = [unpushed startNavigationSessionForTrip:trip];
        [pending updateTravelEstimates:estimates forManeuver:next];
        check(@"guidance asked for before the template is pushed draws nothing and loses nothing",
              pending != nil && unpushed.charon_mapView == nil,
              describe(pending));

        // ---- the 17.4 members: the labels are the host probe's, verbatim -----------------------
        // Section 8 of tests/backports/host/carplay/headunit-probe.m asked Apple's own CarPlay the same
        // questions with no head unit attached, and run.sh compares only the labels BOTH sides carry. So
        // every label below is the host's own string: if the port answers differently the run is red,
        // and the rows' effects are what was measured rather than what was intended.
        printf("\n== the 17.4 members, on a session the program holds ==\n");
        {
            charonHost_CPMapTemplate *laneMap = [[charonHost_CPMapTemplate alloc] init];
            UIView *laneCanvas = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, 800.0, 480.0)];
            [laneMap charon_setMapView:laneCanvas];
            charonHost_CPNavigationSession *held =
                [laneMap startNavigationSessionForTrip:[[charonHost_CPTrip alloc] initCharonTrip]];

            // The port's own label, and deliberately NOT the host's: the host's "the PRIVATE -maneuvers
            // ..." reads a private getter with no registry row, while this reads the public 12.0 property,
            // whose default is an empty array rather than nil (CarPlayNavigationSession12.m sets it in
            // -charon_takeTrip:mapTemplate:). Sharing one label across a private getter and a public
            // property is how a diff compares two different questions and calls it agreement.
            check(@"the port's own upcomingManeuvers with nothing set is an empty array",
                  held.upcomingManeuvers != nil && held.upcomingManeuvers.count == 0,
                  describe(held.upcomingManeuvers));
            check(@"currentRoadNameVariants answers nil before anything is set",
                  held.currentRoadNameVariants == nil, describe(held.currentRoadNameVariants));
            check(@"currentLaneGuidance answers nil before anything is set",
                  held.currentLaneGuidance == nil, describe(held.currentLaneGuidance));
            check(@"maneuverState answers 0 before anything is set",
                  held.maneuverState == 0, [NSString stringWithFormat:@"%lu", (unsigned long)held.maneuverState]);
            // Class presence, asked the same way the host asks it, so the two labels are comparable:
            // both sides answer "present" for a class the port or Apple's framework carries.
            check(@"CPLaneGuidance is the class currentLaneGuidance's value is",
                  NSClassFromString(@"charonHost_CPLaneGuidance") != nil, @"present");
            check(@"CPRouteInformation is the class resumeTrip takes",
                  NSClassFromString(@"charonHost_CPRouteInformation") != nil, @"present");

            // A fresh lane guidance answers nil for both of its array properties, which is what Apple's
            // own object answers -- see facts/CarPlay/NavigationSession174.md. The default for a
            // collection property would be @[]; the port keeps nil because the framework does.
            charonHost_CPLaneGuidance *guidance = [[charonHost_CPLaneGuidance alloc] init];
            check(@"a fresh lane guidance's lanes answer nil, not an empty array (measured)",
                  guidance.lanes == nil, describe(guidance.lanes));
            check(@"a fresh lane guidance's instructionVariants answer nil, not an empty array (measured)",
                  guidance.instructionVariants == nil, describe(guidance.instructionVariants));
            check(@"+supportsSecureCoding is YES (NSSecureCoding is in the header, CPLaneGuidance.h:17)",
                  [charonHost_CPLaneGuidance supportsSecureCoding] ? @"YES" : @"NO",
                  [charonHost_CPLaneGuidance supportsSecureCoding] ? @"YES" : @"NO");

            // nil in every one of the six slots, and nil out for all six, which is what the host measured
            // on Apple's own object. The port's initialiser takes them in the header's order.
            charonHost_CPRouteInformation *route =
                [[charonHost_CPRouteInformation alloc] initWithManeuvers:nil laneGuidances:nil
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

        // ---- the session configuration: the labels are the host probe's, verbatim ------------------
        // Section 5 of headunit-probe.m asked Apple's own CPSessionConfiguration these with no head unit
        // attached. The split the port draws is the header's own: the class, the designated initialiser
        // and the readwrite delegate are the application's and are carried; the two readonly values are
        // the connected CarPlay system's and are inert -- the symbol loads and nothing applies it.
        printf("\n== the session configuration, with no head unit ==\n");
        {
            charonHost_CPSessionConfiguration *configuration =
                [[charonHost_CPSessionConfiguration alloc] initWithDelegate:nil];
            // The word, not the class name: the port's class is compiled under its renamed name, so a
            // class name here could never agree with the host's. See the same note in the probe.
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

            // The two values have no public setter -- both are readonly in CPSessionConfiguration.h --
            // and both writers the release has are private. So the port's own object is asked whether it
            // answers one, which is the check that would notice a setter appearing.
            check(@"the two values have no public setter: both are readonly in the header",
                  ![configuration respondsToSelector:@selector(setContentStyle:)]
                      && ![configuration respondsToSelector:@selector(setLimitedUserInterfaces:)],
                  @"neither setter is answered");

            // The delegate is the application's own, so this is the port-only half: a delegate a caller
            // sets is answered back, and it is answered weakly, because the header says weak and the
            // configuration must not keep its delegate alive.
            charonHost_TestSessionConfigurationDelegate *delegate =
                [[charonHost_TestSessionConfigurationDelegate alloc] init];
            configuration.delegate = delegate;
            check(@"the delegate answers the delegate a caller set", configuration.delegate == delegate,
                  describe(configuration.delegate));
            __weak charonHost_TestSessionConfigurationDelegate *weakDelegate = configuration.delegate;
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
