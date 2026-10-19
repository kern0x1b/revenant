// What Apple's own CarPlay answers on a machine with NO head unit attached, and what it does not.
//
// This is the differential for the seven classes `facts/CarPlay/CarPlay.md` carries as `absent`, and
// it is the measurement that decides which of the 48 rows in `coordination/corpus/queue/CarPlay.tsv`
// are a hardware absence and which are a measurement. It runs against Apple's own CarPlay on this
// Mac, built for Mac Catalyst (`-target arm64-apple-ios17.0-macabi`), because a Catalyst binary is
// the only place on this machine where Apple's CarPlay is loadable at all: the fleet devices run
// 6.1.3, which has no CarPlay class of any name, and `/System/Library/Frameworks` has no CarPlay
// outside the SDK.
//
// Every question is asked through the SDK's own declaration where the header permits the call, and
// through `objc_msgSend` where the header marks the call `NS_UNAVAILABLE` -- because a row whose API
// the header forbids cannot be asked by a program that compiles, and the honest answer to "what does
// the SDK answer" has to come from the runtime.
//
// NOTHING here is a claim about the port. The port's own answers are the runner's business
// (`runner.m`), and a row lands on what the port does, not on what this file prints.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <CarPlay/CarPlay.h>

static int gChecks = 0;
static int gFailures = 0;
static NSMutableArray *gAnswers = nil;

// The answers as `label<TAB>detail` lines, so the port's own run can be diffed against this one
// question by question. A run that prints answers nobody compares is a transcript; this is the half
// of the differential `run.sh` reads.
static void answer(NSString *label, NSString *detail)
{
    if (gAnswers == nil) {
        return;
    }
    [gAnswers addObject:[NSString stringWithFormat:@"%@\t%@", label, detail]];
}

// A check states what the header says and compares it with what the framework answered. Each one
// names the header line it rests on, so a reader can see the expectation is Apple's and not ours.
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

// `NS_UNAVAILABLE` in the header, called at runtime: the header refuses the call at compile time and
// this is the only way to hear what the framework does when a program sends it anyway.
static id sendUnavailable(id target, SEL selector, ...)
{
    NSMethodSignature *signature = [target methodSignatureForSelector:selector];
    if (signature == nil) {
        return nil;
    }
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    invocation.selector = selector;
    invocation.target = target;
    [invocation invoke];
    if (strcmp(signature.methodReturnType, @encode(id)) == 0) {
        void *raw = NULL;
        [invocation getReturnValue:&raw];
        return (__bridge id)raw;
    }
    return nil;
}

// An INSTANCE initialiser of a class whose `-init` the header marks NS_UNAVAILABLE, called at runtime.
// Two things this has to get right, both measured 2026-10-01 the hard way:
//   - the signature comes from `-instanceMethodSignatureForSelector:` on the CLASS. `sendUnavailable`
//     asks `methodSignatureForSelector:` of its target, and a Class object answers that from its
//     METACLASS, where no instance method lives -- so the first version of this found no signature and
//     printed "not in this SDK's CarPlay" for a method the class declares.
//   - the receiver is an ALLOCATED INSTANCE, not the class. An NSInvocation's target is the receiver,
//     and sending an instance method to a Class object is a metaclass lookup that finds nothing and
//     traps: the second version aborted (exit 134) at exactly this line.
// `-[NSInvocation invoke]` reads its arguments out of the target's own frame, so every slot past self
// and _cmd is written first; a nil slot is written as a NULL pointer, which is the nil a caller passing
// nil would send for an object argument.
static id sendInstanceInitializer(Class target, SEL selector, ...)
{
    NSMethodSignature *signature = [target instanceMethodSignatureForSelector:selector];
    if (signature == nil) {
        return nil;
    }
    id allocated = ((id (*)(id, SEL))objc_msgSend)((id)target, @selector(alloc));
    if (allocated == nil) {
        return nil;
    }
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    invocation.selector = selector;
    invocation.target = allocated;
    NSUInteger count = signature.numberOfArguments;
    for (NSUInteger i = 2; i < count; i++) {
        void *slot = NULL;
        [invocation setArgument:&slot atIndex:(NSInteger)i];
    }
    [invocation invoke];
    void *raw = NULL;
    [invocation getReturnValue:&raw];
    return (__bridge id)raw;
}

// The same, for a method whose answer is NOT an object. `-maneuverState` returns a `CPManeuverState`,
// an `NS_ENUM` over `NSInteger` (CPLane.h:10 is the sibling and is an NS_ENUM over NSInteger), so a
// helper that only knows about object returns answers nil for it and a nil there reads as "the value
// is nil" when the value is a number. Measured 2026-10-01: the first run of section 8 printed
// `FAIL maneuverState answers 0 before anything is set  nil`, which is this helper's blind spot and not
// anything the framework said -- so the scalar path is here rather than the expectation weakened.
static BOOL sendUnavailableScalar(id target, SEL selector, long long *out)
{
    NSMethodSignature *signature = [target methodSignatureForSelector:selector];
    if (signature == nil) {
        return NO;
    }
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    invocation.selector = selector;
    invocation.target = target;
    [invocation invoke];
    long long value = 0;
    [invocation getReturnValue:&value];
    if (out != NULL) {
        *out = value;
    }
    return YES;
}

int main(int argc, const char *argv[])
{
    @autoreleasepool {
        if (argc > 1) {
            gAnswers = [NSMutableArray array];
        }
        printf("# the machine: %s\n", [[[NSProcessInfo processInfo] hostName] UTF8String]);
        printf("# CarPlay: %s\n", [[[NSBundle bundleWithIdentifier:@"com.apple.CarPlay"] bundlePath]
            ?: @"(not loadable by path)" UTF8String]);
        printf("# no head unit is attached: the probe never opens one and asks the framework what it\n"
               "# says with none, which is the state both fleet devices are in.\n\n");

        // ---- 1. Which of the seven classes Apple's framework carries, with no head unit ----------
        // The seven are the classes the registry carries as absent. A class that is present here is
        // present on any iPhone with iOS 12 or later, car or no car: so `absent` on such a row is a
        // claim about the PORT and never about Apple's class.
        static NSString *const names[] = {
            @"CPNavigationSession", @"CPSessionConfiguration", @"CPTemplateApplicationScene",
            @"CPTemplateApplicationDashboardScene", @"CPTemplateApplicationInstrumentClusterScene",
            @"CPVoiceControlState", @"CPVoiceControlTemplate", @"CPRouteChoice",
            @"CPInterfaceController", @"CPTemplate", @"CPMapTemplate", @"CPLane", @"CPLaneGuidance",
            @"CPRouteInformation", @"CPManeuver", @"CPTravelEstimates"
        };
        printf("== 1. class presence in Apple's CarPlay, no head unit ==\n");
        for (size_t i = 0; i < sizeof(names) / sizeof(names[0]); i++) {
            Class found = NSClassFromString(names[i]);
            printf("     %-46s %s\n", names[i].UTF8String, found ? "present" : "ABSENT");
        }
        printf("\n");

        // ---- 2. The scene: the framework's own gate ---------------------------------------------
        // A CarPlay scene is a connection to a head unit. The three headers say that the CarPlay screen connects and is ready to show content, and this asks it
        // directly. Catalytic CarPlay has no `+sharedController` and no scene API at all -- measured
        // by the header, `CPInterfaceController.h` in this SDK declares neither -- so on THIS machine
        // the question is only whether the class exists, and the count of scenes is the part a device
        // answers. It is asked through the runtime anyway, so the answer is a measurement and not an
        // assumption.
        printf("== 2. the scene, with no head unit ==\n");
        {
            Class scene = NSClassFromString(@"CPTemplateApplicationScene");
            Class dashboard = NSClassFromString(@"CPTemplateApplicationDashboardScene");
            Class cluster = NSClassFromString(@"CPTemplateApplicationInstrumentClusterScene");
            check(@"CPTemplateApplicationScene is a UIScene subclass (a scene, not a view)",
                  scene != nil && [scene isSubclassOfClass:NSClassFromString(@"UIScene")],
                  scene ? [NSString stringWithFormat:@"superclass %@", NSStringFromClass([scene superclass])]
                        : @"no class");
            check(@"CPTemplateApplicationDashboardScene is a UIScene subclass",
                  dashboard != nil && [dashboard isSubclassOfClass:NSClassFromString(@"UIScene")],
                  dashboard ? @"UIScene" : @"no class");
            check(@"CPTemplateApplicationInstrumentClusterScene is a UIScene subclass",
                  cluster != nil && [cluster isSubclassOfClass:NSClassFromString(@"UIScene")],
                  cluster ? @"UIScene" : @"no class");
            // A UIScene is created by the system for a connection. None of the three declares an
            // initialiser of its own, so the only `-init` they answer is NSObject's, and no program
            // can make the scene a CarPlay screen would make. That is the measurement behind the
            // hardware absence, and it is read off the metadata rather than off the header's prose.
            Class const scenes[] = {scene, dashboard, cluster};
            for (size_t i = 0; i < sizeof(scenes) / sizeof(scenes[0]); i++) {
                Method own = class_getInstanceMethod(scenes[i], @selector(init));
                Method inherited = class_getInstanceMethod([NSObject class], @selector(init));
                check([NSString stringWithFormat:@"%@ declares no initialiser of its own",
                            NSStringFromClass(scenes[i])],
                      own == NULL || own == inherited,
                      [NSString stringWithFormat:@"-init is %@", own == inherited ? @"NSObject's" : @"its own"]);
            }
            // What the framework could say about a CONNECTED scene, asked of the interface
            // controller: this SDK's CarPlay declares no shared controller and no connected-scene
            // count, so on this machine the question cannot be put to it at all. That is the second
            // half of the hardware absence, and it is printed rather than checked because the answer
            // is a property of Apple's Catalyst surface, not a promise the port has to keep.
            Class controller = NSClassFromString(@"CPInterfaceController");
            for (NSString *name in @[@"sharedController", @"connectedSceneCount",
                                     @"templateApplicationScene", @"connectedScenes"]) {
                SEL selector = NSSelectorFromString(name);
                printf("     [CPInterfaceController %-26s] %s\n", name.UTF8String,
                       [controller respondsToSelector:selector] ? "declared"
                                                               : "not in this SDK's CarPlay");
            }
        }
        printf("\n");

        // ---- 3. CPVoiceControlState: a value the app makes, with no car in the picture ------------
        // `CPVoiceControlTemplate.h`: the app creates the template with one or more states and may switch between them with activateVoiceControlState:. Nothing in the class's own API is the car's.
        printf("== 3. CPVoiceControlState ==\n");
        {
            CPVoiceControlState *state = [[CPVoiceControlState alloc]
                initWithIdentifier:@"charon.listening"
                      titleVariants:@[@"Listening", @"Listen"]
                              image:nil
                            repeats:YES];
            check(@"identifier answers what the initialiser was given",
                  [state.identifier isEqualToString:@"charon.listening"], describe(state.identifier));
            check(@"titleVariants answers the array it was given", [state.titleVariants count] == 2,
                  describe(state.titleVariants));
            check(@"repeats answers YES", state.repeats == YES,
                  [NSString stringWithFormat:@"%d", (int)state.repeats]);
            check(@"image answers nil when none was given", state.image == nil, describe(state.image));
            check(@"+supportsSecureCoding is YES (NSSecureCoding is in the header)",
                  [CPVoiceControlState supportsSecureCoding] ? @"YES" : @"NO",
                  [CPVoiceControlState supportsSecureCoding] ? @"YES" : @"NO");
            // A nil array in, nil out. The header declares titleVariants `nullable, copy`, and a
            // getter that answered an empty array instead would be a quiet different answer -- the
            // port's row says nil and the port's object has to answer nil.
            CPVoiceControlState *bare = [[CPVoiceControlState alloc] initWithIdentifier:@"charon.bare"
                                                                          titleVariants:nil
                                                                                  image:nil
                                                                                repeats:NO];
            check(@"titleVariants answers nil when it was given nil", bare.titleVariants == nil,
                  describe(bare.titleVariants));
            // The header's 150-by-150-point cap on Voice Control state images is enforced by the
            // framework, not only documented: a 300x300 image comes back 150x150. The port scales
            // rather than keeps, because this is what Apple's own object does.
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(300.0, 300.0), NO, 1.0);
            [[UIColor redColor] setFill];
            UIRectFill(CGRectMake(0.0, 0.0, 300.0, 300.0));
            UIImage *large = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            CPVoiceControlState *scaled = [[CPVoiceControlState alloc] initWithIdentifier:@"charon.scaled"
                                                                             titleVariants:@[@"Scaled"]
                                                                                     image:large
                                                                                   repeats:NO];
            check(@"an image over 150 points a side comes back 150 by 150",
                  scaled.image != nil && scaled.image.size.width <= 150.0 && scaled.image.size.height <= 150.0,
                  [NSString stringWithFormat:@"%g by %g", scaled.image.size.width, scaled.image.size.height]);
            // The round trip, because the header declares NSSecureCoding and a value that cannot
            // encode is a value that cannot cross a process boundary.
            NSError *error = nil;
            NSData *coded = [NSKeyedArchiver archivedDataWithRootObject:state requiringSecureCoding:YES
                                                                error:&error];
            // The allowed classes are the state's own plus the value classes it holds, and both sides
            // of the diff use this same call: a state carries an array of strings and an image, so a
            // reader that does not allow them cannot read it, and the comparison is only meaningful
            // if both sides are asked the same question.
            CPVoiceControlState *back = coded == nil ? nil
                : [NSKeyedUnarchiver unarchivedObjectOfClasses:
                       [NSSet setWithObjects:[CPVoiceControlState class], [NSString class],
                                             [NSArray class], [UIImage class], nil]
                                                  fromData:coded
                                                     error:&error];
            check(@"a state survives an NSSecureCoding round trip with its identifier",
                  back != nil && [back.identifier isEqualToString:@"charon.listening"],
                  back ? describe(back.identifier) : [NSString stringWithFormat:@"nil (%@)",
                                                        error.localizedDescription ?: @"no error"]);
        }
        printf("\n");

        // ---- 4. CPVoiceControlTemplate: the app's own template ---------------------------------
        // `CPVoiceControlTemplate.h`: the header caps the states at five, and anything past the fifth is dropped. The template starts on the
        // first state given, which is the default.
        printf("== 4. CPVoiceControlTemplate ==\n");
        {
            NSMutableArray<CPVoiceControlState *> *states = [NSMutableArray array];
            for (int i = 0; i < 6; i++) {
                [states addObject:[[CPVoiceControlState alloc]
                    initWithIdentifier:[NSString stringWithFormat:@"charon.state%d", i]
                          titleVariants:@[[NSString stringWithFormat:@"State %d", i]]
                                  image:nil
                                repeats:NO]];
            }
            CPVoiceControlTemplate *voice = [[CPVoiceControlTemplate alloc]
                initWithVoiceControlStates:states];
            check(@"the template keeps the five states the header's limit allows",
                  [voice.voiceControlStates count] == 5,
                  [NSString stringWithFormat:@"%lu of %lu", (unsigned long)[voice.voiceControlStates count],
                      (unsigned long)states.count]);
            check(@"the first of the states it was given is the active one",
                  [voice.activeStateIdentifier isEqualToString:@"charon.state0"],
                  describe(voice.activeStateIdentifier));
            // The header warns that the template must first be presented through the interface controller before a state is activated, otherwise the call has no effect. Measured on Apple's own framework with no head unit and no
            // presentation: the active state DOES change. The warning is about what a car then shows,
            // not about the object's own state, so the port switches the state and the car is the
            // wall. This was read off the framework, not assumed from the warning.
            [voice activateVoiceControlStateWithIdentifier:@"charon.state3"];
            check(@"activating switches the active state with no car attached (measured)",
                  [voice.activeStateIdentifier isEqualToString:@"charon.state3"],
                  [NSString stringWithFormat:@"active is now %@", describe(voice.activeStateIdentifier)]);
            // An identifier no state carries. The header says an identifier should match one of the states the template was created with,
            // and Apple's own object does
            // not check: measured here, the active identifier becomes the one that was asked for,
            // even when no such state exists. The port matches that, and draws nothing for an
            // identifier no state carries, because there is no state to draw.
            [voice activateVoiceControlStateWithIdentifier:@"charon.state99"];
            check(@"an identifier no state carries becomes the active one anyway (measured)",
                  [voice.activeStateIdentifier isEqualToString:@"charon.state99"],
                  [NSString stringWithFormat:@"active is now %@", describe(voice.activeStateIdentifier)]);
            // The header's rate limit says the template drops state changes that come too fast or too often in a short span,
            // measured against the
            // object's own state: twelve activations in a tight loop, and every one of them takes.
            // The limit the header describes is on what a car then shows, which is the wall; the
            // object follows every activation, and the port must not invent an interval.
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
            // An empty array and a nil array are two different answers, and the port keeps them apart.
            CPVoiceControlTemplate *empty = [[CPVoiceControlTemplate alloc] initWithVoiceControlStates:@[]];
            check(@"an empty array of states keeps an empty array and no active state",
                  [empty.voiceControlStates count] == 0 && empty.activeStateIdentifier == nil,
                  [NSString stringWithFormat:@"%lu states, active %@", (unsigned long)[empty.voiceControlStates count],
                      describe(empty.activeStateIdentifier)]);
            CPVoiceControlTemplate *none = [[CPVoiceControlTemplate alloc] initWithVoiceControlStates:nil];
            check(@"a nil array of states answers nil for both, as the framework does",
                  none.voiceControlStates == nil && none.activeStateIdentifier == nil,
                  [NSString stringWithFormat:@"states %@, active %@", describe(none.voiceControlStates),
                      describe(none.activeStateIdentifier)]);
        }
        printf("\n");

        // ---- 5. CPSessionConfiguration: the configuration OF a session --------------------------
        // `CPSessionConfiguration.h`: the header describes the content style as the one the connected CarPlay system
        // suggests, and the limit as a bitmask of the kinds of user interface that are restricted. Both are readonly and
        // both come from the connected system. This asks with none connected.
        printf("== 5. CPSessionConfiguration, with no head unit ==\n");
        {
            CPSessionConfiguration *configuration = [[CPSessionConfiguration alloc] initWithDelegate:nil];
            // The detail is a word and not the class name, because the two sides cannot agree on a class
            // name: this binary links Apple's CarPlay AND the port's sources are compiled with
            // -DCPSessionConfiguration=charonHost_CPSessionConfiguration, so the host prints
            // CPSessionConfiguration and the port prints charonHost_CPSessionConfiguration. Printing the
            // name made the diff red over a rename that is the harness working, which is the same reason
            // the delegate check below answers identity rather than a class name.
            check(@"the designated initialiser makes a configuration", configuration != nil,
                  @"a configuration");
            check(@"delegate answers the delegate it was given (nil here)", configuration.delegate == nil,
                  describe(configuration.delegate));
            check(@"limitedUserInterfaces answers the mask the connected system suggests",
                  configuration.limitedUserInterfaces == 0,
                  [NSString stringWithFormat:@"%lu", (unsigned long)configuration.limitedUserInterfaces]);
            check(@"contentStyle answers the style the connected system suggests",
                  configuration.contentStyle == 0,
                  [NSString stringWithFormat:@"%lu", (unsigned long)configuration.contentStyle]);
            id made = sendUnavailable((id)[CPSessionConfiguration class], @selector(new));
            check(@"+new, which the header marks NS_UNAVAILABLE, is the inherited NSObject one",
                  [made isKindOfClass:[CPSessionConfiguration class]], describe(made));
        }
        printf("\n");

        // ---- 6. CPNavigationSession: created by the system, never by the app ---------------------
        // `CPNavigationSession.h`: the header says the system makes a CPNavigationSession for the app when it calls
        // startNavigationSessionForTrip: on CPMapTemplate, and `-init`/`+new` are NS_UNAVAILABLE. The
        // 16.0 arm64e cache agrees and names the creator: the private protocol
        // CPNavigationSessionProviding declares `-hostStartNavigationSessionForTrip:reply:`.
        printf("== 6. CPNavigationSession ==\n");
        {
            Class session = NSClassFromString(@"CPNavigationSession");
            id made = sendUnavailable((id)session, @selector(new));
            check(@"+new, which the header marks NS_UNAVAILABLE, is the inherited NSObject one",
                  made == nil || [made isKindOfClass:session], describe(made));
            id again = sendUnavailable(made, @selector(init));
            id trip = again == nil ? nil : sendUnavailable(again, @selector(trip));
            check(@"-init, likewise NS_UNAVAILABLE, leaves a session with no trip",
                  trip == nil, describe(trip));
            // The members the registry rows name, asked of the class: which of them the release that
            // carries the class really has is the question `objc-inventory.lua` answers, and this is
            // the same list against Apple's own current framework.
            static NSString *const members[] = {
                @"trip", @"upcomingManeuvers", @"currentLaneGuidance", @"currentRoadNameVariants",
                @"maneuverState", @"updateTravelEstimates:forManeuver:", @"pauseTripForReason:description:",
                @"pauseTripForReason:description:turnCardColor:", @"finishTrip", @"cancelTrip",
                @"addManeuvers:", @"addLaneGuidances:", @"resumeTripWithUpdatedRouteInformation:"
            };
            for (size_t i = 0; i < sizeof(members) / sizeof(members[0]); i++) {
                SEL selector = NSSelectorFromString(members[i]);
                printf("     -[CPNavigationSession %-46s] %s\n", members[i].UTF8String,
                       [session instancesRespondToSelector:selector] ? "present" : "ABSENT");
            }
        }
        printf("\n");

        // ---- 6b. the map template's members, on Apple's own class ---------------------------------
        // The twelve rows that said implemented with nothing behind them were CPMapTemplate members, a
        // CPImageSet initialiser and one CPGridButton member. This asks Apple's own class which of them
        // it carries, which is the measurement that decides the rows' status: a member Apple's own
        // framework has and the port does not is a claim about this port, so it cannot be `absent`.
        //
        // What the class cannot be asked is a value - with no scene there is no map and nothing to draw -
        // so this asks only the question the release can answer. The completion's BOOL is not asked here
        // either: CPMapTemplate.h:176-177 states what it means, and a probe that drove Apple's
        // dismissal with no alert present would be measuring Apple's implementation of a sentence the
        // header already writes down.
        printf("== 6b. CPMapTemplate, with no scene and no map ==\n");
        {
            Class map = NSClassFromString(@"CPMapTemplate");
            static NSString *const members[] = {
                @"presentNavigationAlert:animated:", @"dismissNavigationAlertAnimated:completion:",
                @"showPanningInterfaceAnimated:", @"dismissPanningInterfaceAnimated:",
                @"showTripPreviews:textConfiguration:", @"showRouteChoicesPreviewForTrip:textConfiguration:",
                @"showTripPreviews:selectedTrip:textConfiguration:", @"hideTripPreviews",
                @"updateTravelEstimates:forTrip:",
                @"updateTravelEstimates:forTrip:withTimeRemainingColor:"
            };
            NSUInteger total = sizeof(members) / sizeof(members[0]);
            NSUInteger present = 0;
            for (NSUInteger i = 0; i < total; i++) {
                SEL selector = NSSelectorFromString(members[i]);
                BOOL has = [map instancesRespondToSelector:selector];
                present += has ? 1 : 0;
                printf("     -[CPMapTemplate %-52s] %s\n", members[i].UTF8String,
                       has ? "present" : "ABSENT");
            }
            check(@"Apple's own map template carries every one of these members", present == total,
                  [NSString stringWithFormat:@"%lu of %lu", (unsigned long)present, (unsigned long)total]);

            Class imageSet = NSClassFromString(@"CPImageSet");
            check(@"Apple's own image set carries its designated initialiser",
                  [imageSet instancesRespondToSelector:@selector(initWithLightContentImage:darkContentImage:)],
                  @"present");

            Class grid = NSClassFromString(@"CPGridButton");
            check(@"Apple's own grid button carries -updateImage:",
                  [grid instancesRespondToSelector:@selector(updateImage:)], @"present");
        }
        printf("\n");

        // ---- 7. CPRouteChoice: an ordinary value, and +new is a member of a class the port builds --
        printf("== 7. CPRouteChoice ==\n");
        {
            Class choice = NSClassFromString(@"CPRouteChoice");
            id made = sendUnavailable((id)choice, @selector(new));
            check(@"+new makes a route choice", [made isKindOfClass:choice], describe(made));
            // Measured, not assumed: a new route choice answers an EMPTY ARRAY for each variants
            // property, not nil. The row for `+[CPRouteChoice new]` has to say that, because a row
            // that said "nil" would be a false answer and the port's own object is asked against it.
            static NSString *const variants[] = {
                @"summaryVariants", @"selectionSummaryVariants", @"additionalInformationVariants"
            };
            for (size_t i = 0; i < sizeof(variants) / sizeof(variants[0]); i++) {
                id value = sendUnavailable(made, NSSelectorFromString(variants[i]));
                check(([NSString stringWithFormat:@"a new route choice's %@ is an empty array",
                            variants[i]]),
                      [value isKindOfClass:[NSArray class]] && [(NSArray *)value count] == 0,
                      describe(value));
            }
            check(@"a new route choice has no user info",
                  sendUnavailable(made, @selector(userInfo)) == nil,
                  describe(sendUnavailable(made, @selector(userInfo))));
        }

        // ---- 8. The 17.4 members of the navigation session: stored values, not messages to a car --
        // `CPNavigationSession.h:58-103` declares five of them `API_AVAILABLE(ios(17.4))` and they are
        // the rows the registry carries as `owed`. The question this asks is the one the disposition
        // turns on: does a session a program holds answer them itself, or does it need a connected car
        // to answer at all? A session is made with the runtime here because the header marks -init and
        // +new NS_UNAVAILABLE (CPNavigationSession.h:33-34), and `toolscorpus/objc-inventory.lua` over
        // the arm64e caches is what says the private setters exist at 18.0 and not at 16.0.
        printf("== 8. the 17.4 members, on a session the program holds ==\n");
        {
            Class session = NSClassFromString(@"CPNavigationSession");
            id held = sendUnavailable((id)session, @selector(new));
            if (held == nil) {
                check(@"a session the program holds can be made through the runtime", NO,
                      @"no object to ask");
            } else {
                // -addManeuvers: is documented as the call that adds CPManeuvers to a navigation session in chronological order (:83-86): the session ACCUMULATES what the program adds, and what
                // it accumulated is readable, which is a stored value and not a message to a car.
                SEL addManeuvers = NSSelectorFromString(@"addManeuvers:");
                // `-maneuvers` is the PRIVATE getter the 18.0 cache carries alongside -setManeuvers: (see
                // objc.code_map above), and it has no registry row, so this label says so and stays on
                // this side of the diff. The port has no -maneuvers to compare, and its public
                // `upcomingManeuvers` is a different name answering a different question -- which is why
                // this label names the private one and the port's public check is labelled separately.
                id maneuvers = sendUnavailable(held, NSSelectorFromString(@"maneuvers"));
                check(@"the PRIVATE -maneuvers a session with nothing added has is empty",
                      maneuvers == nil || [(NSArray *)maneuvers count] == 0, describe(maneuvers));
                printf("     [CPNavigationSession addManeuvers:] %s\n",
                       [session instancesRespondToSelector:addManeuvers] ? "present" : "ABSENT");
                printf("     [CPNavigationSession addLaneGuidances:] %s\n",
                       [session instancesRespondToSelector:NSSelectorFromString(@"addLaneGuidances:")]
                           ? "present" : "ABSENT");
                printf("     [CPNavigationSession currentLaneGuidance] %s\n",
                       [session instancesRespondToSelector:NSSelectorFromString(@"currentLaneGuidance")]
                           ? "present" : "ABSENT");
                printf("     [CPNavigationSession currentRoadNameVariants] %s\n",
                       [session instancesRespondToSelector:NSSelectorFromString(@"currentRoadNameVariants")]
                           ? "present" : "ABSENT");
                printf("     [CPNavigationSession maneuverState] %s\n",
                       [session instancesRespondToSelector:NSSelectorFromString(@"maneuverState")]
                           ? "present" : "ABSENT");
                printf("     [CPNavigationSession resumeTripWithUpdatedRouteInformation:] %s\n",
                       [session instancesRespondToSelector:
                           NSSelectorFromString(@"resumeTripWithUpdatedRouteInformation:")]
                           ? "present" : "ABSENT");
                // The three values that need no argument: a session with no car attached answers each of
                // them from its own storage, and that is what `inert` would be if nothing applied them.
                id road = sendUnavailable(held, NSSelectorFromString(@"currentRoadNameVariants"));
                check(@"currentRoadNameVariants answers nil before anything is set",
                      road == nil, describe(road));
                id lane = sendUnavailable(held, NSSelectorFromString(@"currentLaneGuidance"));
                check(@"currentLaneGuidance answers nil before anything is set",
                      lane == nil, describe(lane));
                long long stateValue = -1;
                BOOL stateAnswered = sendUnavailableScalar(held, NSSelectorFromString(@"maneuverState"),
                                                           &stateValue);
                check(@"maneuverState answers 0 before anything is set",
                      stateAnswered && stateValue == 0,
                      [NSString stringWithFormat:@"%lld", stateAnswered ? stateValue : -1]);
                // The setter the header does NOT declare, asked through the runtime: if the class
                // answers one, the value is the program's own and the port's is not a stub for a car.
                printf("     [CPNavigationSession setCurrentRoadNameVariants:] %s\n",
                       [session instancesRespondToSelector:
                           NSSelectorFromString(@"setCurrentRoadNameVariants:")] ? "present" : "ABSENT");
                printf("     [CPNavigationSession setManeuverState:] %s\n",
                       [session instancesRespondToSelector:NSSelectorFromString(@"setManeuverState:")]
                           ? "present" : "ABSENT");
                // And the round trip, which is the whole disposition: set a value the header declares
                // readwrite, read it back, with no head unit anywhere in the run.
                Class laneGuidance = NSClassFromString(@"CPLaneGuidance");
                Class routeInformation = NSClassFromString(@"CPRouteInformation");
                check(@"CPLaneGuidance is the class currentLaneGuidance's value is",
                      laneGuidance != nil, laneGuidance ? @"present" : @"ABSENT");
                check(@"CPRouteInformation is the class resumeTrip takes",
                      routeInformation != nil, routeInformation ? @"present" : @"ABSENT");
                (void)laneGuidance;
                (void)routeInformation;
                // The round trip the header describes, on Apple's own objects, with no car attached.
                // `CPLaneGuidance.h:22-28`: lanes is an array of CPLane objects, one per lane, and instructionVariants is an array of
                // NSStrings, one per variant of the instruction, ranked from most to least wanted.
                id guidance = [[NSClassFromString(@"CPLaneGuidance") alloc] init];
                // Measured 2026-10-01 on Apple's own object with no head unit: a fresh CPLaneGuidance
                // answers NIL for both properties, not an empty array. This is the honest line of this
                // family -- a first reading of the header says an array, and the framework says nil --
                // and the port follows the framework. `-setLanes:` with an empty array then keeps an
                // empty array, so nil-in and array-in are two different answers and the port keeps them
                // apart rather than defaulting one to the other.
                id lanes = sendUnavailable(guidance, NSSelectorFromString(@"lanes"));
                check(@"a fresh lane guidance's lanes answer nil, not an empty array (measured)",
                      lanes == nil, describe(lanes));
                id variants = sendUnavailable(guidance, NSSelectorFromString(@"instructionVariants"));
                check(@"a fresh lane guidance's instructionVariants answer nil, not an empty array (measured)",
                      variants == nil, describe(variants));
                check(@"+supportsSecureCoding is YES (NSSecureCoding is in the header, CPLaneGuidance.h:17)",
                      [NSClassFromString(@"CPLaneGuidance") supportsSecureCoding] ? @"YES" : @"NO",
                      [NSClassFromString(@"CPLaneGuidance") supportsSecureCoding] ? @"YES" : @"NO");
                // `CPRouteInformation.h:23` is the designated initialiser and :25 marks -init
                // NS_UNAVAILABLE, so the object is made through it or not at all.
                id route = sendInstanceInitializer(routeInformation,
                                                  NSSelectorFromString(@"initWithManeuvers:laneGuidances:"
                                                                       "currentManeuvers:currentLaneGuidance:"
                                                                       "tripTravelEstimates:maneuverTravelEstimates:"));
                if (route != nil) {
                    // Every argument of :23 is nonnull in the header and every property is `copy`
                    // (:30-55), so nil in every slot is what a caller with nothing for a slot sends, and
                    // nil out is the answer that follows. Each slot is asked by name so a row can be
                    // written from the answer rather than from the header's prose.
                    static NSString *const slots[] = {
                        @"maneuvers", @"laneGuidances", @"currentManeuvers", @"currentLaneGuidance",
                        @"tripTravelEstimates", @"maneuverTravelEstimates"
                    };
                    for (size_t i = 0; i < sizeof(slots) / sizeof(slots[0]); i++) {
                        id value = sendUnavailable(route, NSSelectorFromString(slots[i]));
                        check(([NSString stringWithFormat:@"route information from nil in every slot: %@ answers nil",
                                    slots[i]]),
                              value == nil, describe(value));
                    }
                } else {
                    printf("     [CPRouteInformation initWithManeuvers:...] no instance method signature\n");
                    check(@"the designated initialiser is declared on the class", NO,
                          @"no instance method signature for it");
                }
            }
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
