#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <CarPlay/CarPlay.h>

static int gChecks = 0;
static int gFailures = 0;
static NSMutableArray *gAnswers = nil;

static void answer(NSString *label, NSString *detail)
{
    if (gAnswers == nil) {
        return;
    }
    [gAnswers addObject:[NSString stringWithFormat:@"%@\t%@", label, detail]];
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
            Class const scenes[] = {scene, dashboard, cluster};
            for (size_t i = 0; i < sizeof(scenes) / sizeof(scenes[0]); i++) {
                Method own = class_getInstanceMethod(scenes[i], @selector(init));
                Method inherited = class_getInstanceMethod([NSObject class], @selector(init));
                check([NSString stringWithFormat:@"%@ declares no initialiser of its own",
                            NSStringFromClass(scenes[i])],
                      own == NULL || own == inherited,
                      [NSString stringWithFormat:@"-init is %@", own == inherited ? @"NSObject's" : @"its own"]);
            }
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

        printf("== 3. CPVoiceControlState ==\n");
        {
            CPVoiceControlState *state = [[CPVoiceControlState alloc]
                initWithIdentifier:@"revenant.listening"
                      titleVariants:@[@"Listening", @"Listen"]
                              image:nil
                            repeats:YES];
            check(@"identifier answers what the initialiser was given",
                  [state.identifier isEqualToString:@"revenant.listening"], describe(state.identifier));
            check(@"titleVariants answers the array it was given", [state.titleVariants count] == 2,
                  describe(state.titleVariants));
            check(@"repeats answers YES", state.repeats == YES,
                  [NSString stringWithFormat:@"%d", (int)state.repeats]);
            check(@"image answers nil when none was given", state.image == nil, describe(state.image));
            check(@"+supportsSecureCoding is YES (NSSecureCoding is in the header)",
                  [CPVoiceControlState supportsSecureCoding] ? @"YES" : @"NO",
                  [CPVoiceControlState supportsSecureCoding] ? @"YES" : @"NO");
            CPVoiceControlState *bare = [[CPVoiceControlState alloc] initWithIdentifier:@"revenant.bare"
                                                                          titleVariants:nil
                                                                                  image:nil
                                                                                repeats:NO];
            check(@"titleVariants answers nil when it was given nil", bare.titleVariants == nil,
                  describe(bare.titleVariants));
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(300.0, 300.0), NO, 1.0);
            [[UIColor redColor] setFill];
            UIRectFill(CGRectMake(0.0, 0.0, 300.0, 300.0));
            UIImage *large = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            CPVoiceControlState *scaled = [[CPVoiceControlState alloc] initWithIdentifier:@"revenant.scaled"
                                                                             titleVariants:@[@"Scaled"]
                                                                                     image:large
                                                                                   repeats:NO];
            check(@"an image over 150 points a side comes back 150 by 150",
                  scaled.image != nil && scaled.image.size.width <= 150.0 && scaled.image.size.height <= 150.0,
                  [NSString stringWithFormat:@"%g by %g", scaled.image.size.width, scaled.image.size.height]);
            NSError *error = nil;
            NSData *coded = [NSKeyedArchiver archivedDataWithRootObject:state requiringSecureCoding:YES
                                                                error:&error];
            CPVoiceControlState *back = coded == nil ? nil
                : [NSKeyedUnarchiver unarchivedObjectOfClasses:
                       [NSSet setWithObjects:[CPVoiceControlState class], [NSString class],
                                             [NSArray class], [UIImage class], nil]
                                                  fromData:coded
                                                     error:&error];
            check(@"a state survives an NSSecureCoding round trip with its identifier",
                  back != nil && [back.identifier isEqualToString:@"revenant.listening"],
                  back ? describe(back.identifier) : [NSString stringWithFormat:@"nil (%@)",
                                                        error.localizedDescription ?: @"no error"]);
        }
        printf("\n");

        printf("== 4. CPVoiceControlTemplate ==\n");
        {
            NSMutableArray<CPVoiceControlState *> *states = [NSMutableArray array];
            for (int i = 0; i < 6; i++) {
                [states addObject:[[CPVoiceControlState alloc]
                    initWithIdentifier:[NSString stringWithFormat:@"revenant.state%d", i]
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

        printf("== 5. CPSessionConfiguration, with no head unit ==\n");
        {
            CPSessionConfiguration *configuration = [[CPSessionConfiguration alloc] initWithDelegate:nil];
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

        printf("== 7. CPRouteChoice ==\n");
        {
            Class choice = NSClassFromString(@"CPRouteChoice");
            id made = sendUnavailable((id)choice, @selector(new));
            check(@"+new makes a route choice", [made isKindOfClass:choice], describe(made));
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

        printf("== 8. the 17.4 members, on a session the program holds ==\n");
        {
            Class session = NSClassFromString(@"CPNavigationSession");
            id held = sendUnavailable((id)session, @selector(new));
            if (held == nil) {
                check(@"a session the program holds can be made through the runtime", NO,
                      @"no object to ask");
            } else {
                SEL addManeuvers = NSSelectorFromString(@"addManeuvers:");
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
                printf("     [CPNavigationSession setCurrentRoadNameVariants:] %s\n",
                       [session instancesRespondToSelector:
                           NSSelectorFromString(@"setCurrentRoadNameVariants:")] ? "present" : "ABSENT");
                printf("     [CPNavigationSession setManeuverState:] %s\n",
                       [session instancesRespondToSelector:NSSelectorFromString(@"setManeuverState:")]
                           ? "present" : "ABSENT");
                Class laneGuidance = NSClassFromString(@"CPLaneGuidance");
                Class routeInformation = NSClassFromString(@"CPRouteInformation");
                check(@"CPLaneGuidance is the class currentLaneGuidance's value is",
                      laneGuidance != nil, laneGuidance ? @"present" : @"ABSENT");
                check(@"CPRouteInformation is the class resumeTrip takes",
                      routeInformation != nil, routeInformation ? @"present" : @"ABSENT");
                (void)laneGuidance;
                (void)routeInformation;
                id guidance = [[NSClassFromString(@"CPLaneGuidance") alloc] init];
                id lanes = sendUnavailable(guidance, NSSelectorFromString(@"lanes"));
                check(@"a fresh lane guidance's lanes answer nil, not an empty array (measured)",
                      lanes == nil, describe(lanes));
                id variants = sendUnavailable(guidance, NSSelectorFromString(@"instructionVariants"));
                check(@"a fresh lane guidance's instructionVariants answer nil, not an empty array (measured)",
                      variants == nil, describe(variants));
                check(@"+supportsSecureCoding is YES (NSSecureCoding is in the header, CPLaneGuidance.h:17)",
                      [NSClassFromString(@"CPLaneGuidance") supportsSecureCoding] ? @"YES" : @"NO",
                      [NSClassFromString(@"CPLaneGuidance") supportsSecureCoding] ? @"YES" : @"NO");
                id route = sendInstanceInitializer(routeInformation,
                                                  NSSelectorFromString(@"initWithManeuvers:laneGuidances:"
                                                                       "currentManeuvers:currentLaneGuidance:"
                                                                       "tripTravelEstimates:maneuverTravelEstimates:"));
                if (route != nil) {
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
