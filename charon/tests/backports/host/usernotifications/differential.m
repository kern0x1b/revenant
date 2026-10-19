#import <UserNotifications/UserNotifications.h>
#import <objc/message.h>
#import <objc/runtime.h>

static int checks, failures;


static void fail(NSString *format, ...)
{
    va_list arguments;
    va_start(arguments, format);
    printf("FAIL %s\n", [[NSString alloc] initWithFormat:format arguments:arguments].UTF8String);
    va_end(arguments);
    failures++;
}

static NSString *plain(id value)
{
    NSString *text = [value description] ?: @"(nil)";
    text = [text stringByReplacingOccurrencesOfString:@"CharonHost" withString:@""];
    return [[NSRegularExpression regularExpressionWithPattern:@"0x[0-9a-f]+" options:0 error:NULL]
               stringByReplacingMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:@"0x"];
}

static void same(id ours, id theirs, NSString *what)
{
    checks++;
    if ([plain(ours) isEqualToString:plain(theirs)])
        return;
    fail(@"%@: ours %@, UserNotifications %@", what, plain(ours), plain(theirs));
}

static Class ours(Class theirs)
{
    return NSClassFromString([@"CharonHost" stringByAppendingString:NSStringFromClass(theirs)]);
}

static NSString *raised(void (^block)(void))
{
    @try {
        block();
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason];
    }
    return @"nothing";
}

static id call(id target, SEL selector)
{
    return ((id (*)(id, SEL))objc_msgSend)(target, selector);
}

static NSString *flag(BOOL value)
{
    return value ? @"YES" : @"NO";
}

static id interval_trigger(Class cls, NSTimeInterval interval, BOOL repeats)
{
    return ((id (*)(id, SEL, NSTimeInterval, BOOL))objc_msgSend)(cls, @selector(triggerWithTimeInterval:repeats:), interval, repeats);
}

static id calendar_trigger(Class cls, NSDateComponents *components, BOOL repeats)
{
    return ((id (*)(id, SEL, id, BOOL))objc_msgSend)(cls, @selector(triggerWithDateMatchingComponents:repeats:), components, repeats);
}

static id round_trip(id object, Class decodedAs, NSString *archivedName)
{
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initRequiringSecureCoding:NO];
    [archiver encodeObject:object forKey:@"root"];
    [archiver finishEncoding];
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:archiver.encodedData error:NULL];
    unarchiver.requiresSecureCoding = NO;
    if (decodedAs)
        [unarchiver setClass:decodedAs forClassName:archivedName];
    return [unarchiver decodeObjectForKey:@"root"];
}

static void compare_triggers(void)
{
    Class interval = ours([UNTimeIntervalNotificationTrigger class]), calendar = ours([UNCalendarNotificationTrigger class]);
    const struct { NSTimeInterval seconds; BOOL repeats; } asked[] = {
        {0, NO}, {-1, NO}, {NAN, NO}, {0, YES}, {30, YES}, {59.9, YES}, {60, YES}, {5, NO}, {1e9, NO}};
    for (unsigned index = 0; index < sizeof(asked) / sizeof(*asked); index++) {
        NSTimeInterval seconds = asked[index].seconds;
        BOOL repeats = asked[index].repeats;
        NSString *what = [NSString stringWithFormat:@"a time interval trigger of %g, repeats %@", seconds, flag(repeats)];
        same(raised(^{ interval_trigger(interval, seconds, repeats); }),
             raised(^{ interval_trigger([UNTimeIntervalNotificationTrigger class], seconds, repeats); }), what);
    }
    id mine = interval_trigger(interval, 5, NO);
    UNTimeIntervalNotificationTrigger *theirs = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:5 repeats:NO];
    same(mine, theirs, @"a time interval trigger's description");
    same(flag([mine isEqual:interval_trigger(interval, 5, NO)]), flag([theirs isEqual:[UNTimeIntervalNotificationTrigger triggerWithTimeInterval:5 repeats:NO]]),
         @"two time interval triggers alike are equal");
    same(flag([mine isEqual:interval_trigger(interval, 6, NO)]), flag([theirs isEqual:[UNTimeIntervalNotificationTrigger triggerWithTimeInterval:6 repeats:NO]]),
         @"two time interval triggers of different intervals");
    same(flag([mine copy] == mine), flag([theirs copy] == theirs), @"a trigger's copy is itself");
    checks++;
    double ahead = [call(mine, @selector(nextTriggerDate)) timeIntervalSinceNow];
    if (fabs(ahead - 5) > 0.5)
        fail(@"a time interval trigger's next date is %g seconds ahead, not 5", ahead);
    same(round_trip(mine, interval, @"UNTimeIntervalNotificationTrigger"), mine, @"a time interval trigger archived");
    checks++;
    if (((NSTimeInterval (*)(id, SEL))objc_msgSend)(round_trip(theirs, interval, @"UNTimeIntervalNotificationTrigger"), @selector(timeInterval)) != 5)
        fail(@"the system's archive of a time interval trigger does not read back to 5 seconds");

    NSArray *specs = @[@{@"hour": @8, @"minute": @30}, @{@"second": @0}, @{@"minute": @15}, @{@"weekday": @2, @"hour": @9},
                       @{@"day": @31}, @{@"month": @2, @"day": @29}, @{@"month": @3}, @{@"year": @2001}, @{@"year": @2099},
                       @{@"day": @1, @"hour": @0}, @{@"hour": @23, @"minute": @59, @"second": @59}, @{@"weekday": @6, @"weekdayOrdinal": @2}];
    for (NSDictionary *spec in specs) {
        NSDateComponents *components = [[NSDateComponents alloc] init];
        for (NSString *key in spec)
            [components setValue:spec[key] forKey:key];
        for (NSNumber *repeats in @[@NO, @YES]) {
            id a = calendar_trigger(calendar, components, repeats.boolValue);
            UNCalendarNotificationTrigger *b = [UNCalendarNotificationTrigger triggerWithDateMatchingComponents:components
                                                                                                         repeats:repeats.boolValue];
            NSString *what = [NSString stringWithFormat:@"a calendar trigger for %@, repeats %@",
                              [[spec.allKeys sortedArrayUsingSelector:@selector(compare:)] componentsJoinedByString:@","], repeats];
            same(call(a, @selector(nextTriggerDate)), b.nextTriggerDate, [what stringByAppendingString:@" next fires"]);
            same(a, b, [what stringByAppendingString:@" described"]);
            same(call(round_trip(a, calendar, @"UNCalendarNotificationTrigger"), @selector(dateComponents)), components,
                 [what stringByAppendingString:@" archived"]);
            same(call(round_trip(b, calendar, @"UNCalendarNotificationTrigger"), @selector(dateComponents)), components,
                 [what stringByAppendingString:@" read from the system's archive"]);
        }
    }
}

static NSDate *next_after(id trigger, NSDate *after, NSDate *requested)
{
    return ((id (*)(id, SEL, id, id))objc_msgSend)(trigger, NSSelectorFromString(@"nextTriggerDateAfterDate:withRequestedDate:"),
                                                  after, requested);
}

static NSArray *matching_specs(void)
{
    return @[@{@"hour": @8, @"minute": @30}, @{@"second": @0}, @{@"minute": @15}, @{@"hour": @2, @"minute": @30},
             @{@"weekday": @2, @"hour": @9}, @{@"weekday": @1}, @{@"day": @31}, @{@"month": @2, @"day": @29},
             @{@"day": @1, @"hour": @0}, @{@"month": @3}, @{@"year": @2030}, @{@"year": @2000},
             @{@"weekday": @6, @"weekdayOrdinal": @2}, @{@"hour": @23, @"minute": @59, @"second": @59},
             @{@"month": @12, @"day": @25, @"hour": @7}, @{@"hour": @0}, @{@"minute": @0, @"second": @30},
             @{@"day": @31, @"hour": @7}, @{@"day": @31, @"hour": @7, @"minute": @5}, @{@"month": @2, @"day": @30},
             @{@"day": @30, @"minute": @10}, @{@"year": @2099}, @{@"year": @2023, @"month": @6},
             @{@"year": @2099, @"month": @2, @"day": @29, @"hour": @6}];
}

static NSArray *matching_zones(void)
{
    return @[@"GMT", @"Asia/Tokyo", @"America/New_York", @"Europe/Berlin", @"Australia/Lord_Howe"];
}

static NSArray *matching_afters(void)
{
    NSMutableArray *afters = [NSMutableArray array];
    for (double offset = 0; offset < 86400.0 * 800; offset += 86400.0 * 37.3 + 3607.7)
        [afters addObject:@(6.5e8 + offset)];
    [afters addObject:@([[NSDate dateWithTimeIntervalSince1970:1616893200] timeIntervalSinceReferenceDate])];
    [afters addObject:@([[NSDate dateWithTimeIntervalSince1970:1615705200] timeIntervalSinceReferenceDate])];
    return afters;
}

static NSDateComponents *components_of(NSDictionary *spec, NSString *zone)
{
    NSDateComponents *components = [[NSDateComponents alloc] init];
    for (NSString *key in spec)
        [components setValue:spec[key] forKey:key];
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    calendar.timeZone = [NSTimeZone timeZoneWithName:zone];
    components.calendar = calendar;
    return components;
}

static NSString *spec_text(NSDictionary *spec)
{
    NSMutableArray *parts = [NSMutableArray array];
    for (NSString *key in [spec.allKeys sortedArrayUsingSelector:@selector(compare:)])
        [parts addObject:[NSString stringWithFormat:@"%@=%@", key, spec[key]]];
    return [parts componentsJoinedByString:@","];
}

static void compare_matching(void)
{
    Class calendar = ours([UNCalendarNotificationTrigger class]), interval = ours([UNTimeIntervalNotificationTrigger class]);
    for (NSString *zone in matching_zones())
        for (NSDictionary *spec in matching_specs())
            for (NSNumber *repeats in @[@NO, @YES])
                for (NSNumber *after in matching_afters()) {
                    NSDateComponents *components = components_of(spec, zone);
                    NSDate *from = [NSDate dateWithTimeIntervalSinceReferenceDate:after.doubleValue];
                    NSDate *requested = [NSDate dateWithTimeIntervalSinceReferenceDate:after.doubleValue - 86400 * 3];
                    same(next_after(calendar_trigger(calendar, components, repeats.boolValue), from, requested),
                         next_after([UNCalendarNotificationTrigger triggerWithDateMatchingComponents:components repeats:repeats.boolValue], from, requested),
                         [NSString stringWithFormat:@"the next %@ in %@ after %@, repeats %@", spec_text(spec), zone, from, repeats]);
                }
    NSDate *requested = [NSDate dateWithTimeIntervalSinceReferenceDate:1000];
    for (NSNumber *repeats in @[@NO, @YES])
        for (NSNumber *after in @[@500, @999, @1000, @1050, @1100, @1150, @1300, @1301, @1e6]) {
            NSDate *from = [NSDate dateWithTimeIntervalSinceReferenceDate:after.doubleValue];
            same(next_after(interval_trigger(interval, 100, repeats.boolValue), from, requested),
                 next_after([UNTimeIntervalNotificationTrigger triggerWithTimeInterval:100 repeats:repeats.boolValue], from, requested),
                 [NSString stringWithFormat:@"a time interval trigger of 100 after %@, repeats %@", after, repeats]);
        }
    for (id pair in @[@[calendar_trigger(calendar, components_of(@{@"hour": @8}, @"GMT"), NO),
                        [UNCalendarNotificationTrigger triggerWithDateMatchingComponents:components_of(@{@"hour": @8}, @"GMT") repeats:NO]],
                      @[interval_trigger(interval, 100, NO), [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:100 repeats:NO]]]) {
        same(raised(^{ next_after(pair[0], nil, requested); }), raised(^{ next_after(pair[1], nil, requested); }),
             [NSString stringWithFormat:@"%@ asked after no date", NSStringFromClass([pair[1] class])]);
        same(raised(^{ next_after(pair[0], requested, nil); }), raised(^{ next_after(pair[1], requested, nil); }),
             [NSString stringWithFormat:@"%@ asked with no requested date", NSStringFromClass([pair[1] class])]);
    }
}

static void write_expectations(void)
{
    Class calendar = [UNCalendarNotificationTrigger class];
    printf("struct charon_matching { const char *zone, *spec; int repeats; double after, next; };\n");
    printf("static const struct charon_matching charon_matchings[] = {\n");
    for (NSString *zone in matching_zones())
        for (NSDictionary *spec in matching_specs())
            for (NSNumber *repeats in @[@NO, @YES])
                for (NSNumber *after in matching_afters()) {
                    NSDate *from = [NSDate dateWithTimeIntervalSinceReferenceDate:after.doubleValue];
                    NSDate *requested = [NSDate dateWithTimeIntervalSinceReferenceDate:after.doubleValue - 86400 * 3];
                    NSDate *next = next_after([calendar triggerWithDateMatchingComponents:components_of(spec, zone) repeats:repeats.boolValue],
                                              from, requested);
                    printf("    {\"%s\", \"%s\", %d, %.17g, %s},\n", zone.UTF8String, spec_text(spec).UTF8String, repeats.intValue,
                           after.doubleValue, next ? [NSString stringWithFormat:@"%.17g", next.timeIntervalSinceReferenceDate].UTF8String : "NAN");
                }
    printf("};\n");
}

static void compare_content(void)
{
    Class content = ours([UNNotificationContent class]), mutable = ours([UNMutableNotificationContent class]);
    Class sound = ours([UNNotificationSound class]);
    NSArray *getters = @[@"title", @"subtitle", @"body", @"badge", @"sound", @"launchImageName", @"userInfo", @"attachments",
                         @"categoryIdentifier", @"threadIdentifier"];
    id fresh = [[content alloc] init];
    UNNotificationContent *freshTheirs = [[UNNotificationContent alloc] init];
    for (NSString *getter in getters)
        same(call(fresh, NSSelectorFromString(getter)), call(freshTheirs, NSSelectorFromString(getter)),
             [@"a fresh content's " stringByAppendingString:getter]);
    id writable = [[mutable alloc] init];
    UNMutableNotificationContent *writableTheirs = [[UNMutableNotificationContent alloc] init];
    for (NSString *getter in @[@"title", @"subtitle", @"body", @"badge", @"launchImageName", @"userInfo", @"attachments",
                               @"categoryIdentifier", @"threadIdentifier"]) {
        SEL setter = NSSelectorFromString([NSString stringWithFormat:@"set%@%@:", [[getter substringToIndex:1] uppercaseString],
                                                                     [getter substringFromIndex:1]]);
        ((void (*)(id, SEL, id))objc_msgSend)(writable, setter, nil);
        ((void (*)(id, SEL, id))objc_msgSend)(writableTheirs, setter, nil);
        same(call(writable, NSSelectorFromString(getter)), call(writableTheirs, NSSelectorFromString(getter)),
             [getter stringByAppendingString:@" set to nil"]);
    }
    for (id pair in @[@[writable, sound], @[writableTheirs, [UNNotificationSound class]]]) {
        id target = pair[0];
        Class sounds = pair[1];
        [target setValue:@"A title" forKey:@"title"];
        [target setValue:@"A subtitle" forKey:@"subtitle"];
        [target setValue:@"A body" forKey:@"body"];
        [target setValue:@7 forKey:@"badge"];
        [target setValue:call(sounds, @selector(defaultSound)) forKey:@"sound"];
        [target setValue:@"Launch" forKey:@"launchImageName"];
        [target setValue:@{@"key": @[@1, @"two"]} forKey:@"userInfo"];
        [target setValue:@"category" forKey:@"categoryIdentifier"];
        [target setValue:@"thread" forKey:@"threadIdentifier"];
    }
    id frozen = [writable copy];
    UNNotificationContent *frozenTheirs = [writableTheirs copy];
    same(NSStringFromClass([frozen class]), NSStringFromClass([frozenTheirs class]), @"a mutable content's copy");
    same(NSStringFromClass([[frozen mutableCopy] class]), NSStringFromClass([[frozenTheirs mutableCopy] class]),
         @"a content's mutable copy");
    same(flag([frozen copy] == frozen), flag([frozenTheirs copy] == frozenTheirs), @"a content's copy is itself");
    same(flag([frozen isEqual:writable]), flag([frozenTheirs isEqual:writableTheirs]), @"a content equals its mutable source");
    same(flag([frozen hash] == [writable hash]), flag(frozenTheirs.hash == writableTheirs.hash), @"and hashes alike");
    for (NSString *getter in getters) {
        if ([getter isEqualToString:@"sound"])
            continue;
        same(call(frozen, NSSelectorFromString(getter)), call(frozenTheirs, NSSelectorFromString(getter)),
             [@"a filled content's " stringByAppendingString:getter]);
        same(call(round_trip(frozen, content, @"UNNotificationContent"), NSSelectorFromString(getter)),
             call(frozenTheirs, NSSelectorFromString(getter)), [@"an archived content's " stringByAppendingString:getter]);
        same(call(round_trip(frozenTheirs, content, @"UNNotificationContent"), NSSelectorFromString(getter)),
             call(frozenTheirs, NSSelectorFromString(getter)), [@"the system's archived content read back, " stringByAppendingString:getter]);
    }
    same(flag([call(frozen, @selector(sound)) isEqual:call(sound, @selector(defaultSound))]),
         flag([frozenTheirs.sound isEqual:UNNotificationSound.defaultSound]), @"the default sound equals the default sound");
    same(flag([call(sound, @selector(defaultSound)) isEqual:((id (*)(id, SEL, id))objc_msgSend)(sound, @selector(soundNamed:), @"a.caf")]),
         flag([UNNotificationSound.defaultSound isEqual:[UNNotificationSound soundNamed:@"a.caf"]]), @"the default sound is not a named one");
    same(flag([((id (*)(id, SEL, id))objc_msgSend)(sound, @selector(soundNamed:), @"a.caf")
                  isEqual:((id (*)(id, SEL, id))objc_msgSend)(sound, @selector(soundNamed:), @"a.caf")]),
         flag([[UNNotificationSound soundNamed:@"a.caf"] isEqual:[UNNotificationSound soundNamed:@"a.caf"]]), @"two sounds of a name are equal");
    for (NSString *later in @[@"summaryArgument", @"summaryArgumentCount", @"targetContentIdentifier", @"interruptionLevel",
                              @"relevanceScore", @"filterCriteria", @"setInterruptionLevel:", @"setRelevanceScore:"]) {
        checks++;
        if ([mutable instancesRespondToSelector:NSSelectorFromString(later)])
            fail(@"%@, which iOS 10 has not got, is answered", later);
    }
}

static void compare_requests(void)
{
    Class request = ours([UNNotificationRequest class]), content = ours([UNNotificationContent class]);
    Class interval = ours([UNTimeIntervalNotificationTrigger class]);
    id (^make)(Class, id, id, id) = ^(Class cls, id identifier, id body, id trigger) {
        return ((id (*)(id, SEL, id, id, id))objc_msgSend)(cls, @selector(requestWithIdentifier:content:trigger:), identifier, body, trigger);
    };
    same(raised(^{ make(request, nil, [[content alloc] init], nil); }),
         raised(^{ make([UNNotificationRequest class], nil, [[UNNotificationContent alloc] init], nil); }), @"a request with no identifier");
    same(raised(^{ make(request, @"id", nil, nil); }), raised(^{ make([UNNotificationRequest class], @"id", nil, nil); }),
         @"a request with no content");
    id a = make(request, @"id", [[content alloc] init], interval_trigger(interval, 5, NO));
    UNNotificationRequest *b = make([UNNotificationRequest class], @"id", [[UNNotificationContent alloc] init],
                                    [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:5 repeats:NO]);
    same(call(a, @selector(identifier)), b.identifier, @"a request's identifier");
    same(flag(call(a, @selector(trigger)) != nil), flag(b.trigger != nil), @"a request keeps its trigger");
    same(flag([a isEqual:make(request, @"id", [[content alloc] init], interval_trigger(interval, 5, NO))]),
         flag([b isEqual:make([UNNotificationRequest class], @"id", [[UNNotificationContent alloc] init],
                              [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:5 repeats:NO])]), @"two requests alike are equal");
    id back = round_trip(a, request, @"UNNotificationRequest");
    same(call(back, @selector(identifier)), b.identifier, @"an archived request's identifier");
    same(call(call(back, @selector(trigger)), @selector(description)), b.trigger.description, @"an archived request's trigger");
}

static id make_action(Class cls, NSString *identifier, NSString *title, NSUInteger options)
{
    return ((id (*)(id, SEL, id, id, NSUInteger))objc_msgSend)(cls, @selector(actionWithIdentifier:title:options:), identifier, title, options);
}

static id make_text_action(Class cls, NSString *identifier, NSString *title, NSUInteger options, NSString *button, NSString *placeholder)
{
    return ((id (*)(id, SEL, id, id, NSUInteger, id, id))objc_msgSend)(
        cls, @selector(actionWithIdentifier:title:options:textInputButtonTitle:textInputPlaceholder:), identifier, title, options, button, placeholder);
}

static id make_category(Class cls, NSString *identifier, NSArray *actions, NSArray *intents, NSUInteger options)
{
    return ((id (*)(id, SEL, id, id, id, NSUInteger))objc_msgSend)(
        cls, @selector(categoryWithIdentifier:actions:intentIdentifiers:options:), identifier, actions, intents, options);
}

static NSString *tail(NSString *description)
{
    NSRange colon = [description rangeOfString:@"identifier:"];
    NSString *from = colon.location == NSNotFound ? description : [description substringFromIndex:colon.location];
    return [from stringByReplacingOccurrencesOfString:@" icon: (null)," withString:@""];
}

static id make_hidden(Class cls, NSArray *actions, NSString *placeholder, NSUInteger options)
{
    return ((id (*)(id, SEL, id, id, id, id, NSUInteger))objc_msgSend)(cls, @selector(categoryWithIdentifier:actions:intentIdentifiers:hiddenPreviewsBodyPlaceholder:options:),
                                                                        @"cat", actions, @[ @"i" ], placeholder, options);
}

static id make_summary(Class cls, NSArray *actions, NSString *placeholder, NSString *format, NSUInteger options)
{
    return ((id (*)(id, SEL, id, id, id, id, id, NSUInteger))objc_msgSend)(cls, @selector(categoryWithIdentifier:actions:intentIdentifiers:hiddenPreviewsBodyPlaceholder:categorySummaryFormat:options:),
                                                                            @"cat", actions, @[ @"i" ], placeholder, format, options);
}

static void compare_hidden_previews(Class ourCategory, Class theirCategory, NSArray *ourActions, NSArray *theirActions)
{
    id plain_ours = make_category(ourCategory, @"cat", ourActions, @[ @"i" ], 1);
    id plain_theirs = make_category(theirCategory, @"cat", theirActions, @[ @"i" ], 1);
    same(call(plain_ours, @selector(hiddenPreviewsBodyPlaceholder)), call(plain_theirs, @selector(hiddenPreviewsBodyPlaceholder)), @"the placeholder of a category made without one");
    same(call(plain_ours, @selector(categorySummaryFormat)), call(plain_theirs, @selector(categorySummaryFormat)), @"the summary format of a category made without one");
    for (NSString *placeholder in @[ @"Hidden", @"", @"%u new" ]) {
        id a = make_hidden(ourCategory, ourActions, placeholder, 9);
        id b = make_hidden(theirCategory, theirActions, placeholder, 9);
        NSString *what = [NSString stringWithFormat:@"a category with the placeholder %@", placeholder];
        same(call(a, @selector(hiddenPreviewsBodyPlaceholder)), call(b, @selector(hiddenPreviewsBodyPlaceholder)), [what stringByAppendingString:@": placeholder"]);
        same(call(a, @selector(categorySummaryFormat)), call(b, @selector(categorySummaryFormat)), [what stringByAppendingString:@": summary format"]);
        same(call(a, @selector(identifier)), call(b, @selector(identifier)), [what stringByAppendingString:@": identifier"]);
        same(@(((NSUInteger (*)(id, SEL))objc_msgSend)(a, @selector(options))), @(((NSUInteger (*)(id, SEL))objc_msgSend)(b, @selector(options))), [what stringByAppendingString:@": options"]);
        same(call(a, @selector(intentIdentifiers)), call(b, @selector(intentIdentifiers)), [what stringByAppendingString:@": intents"]);
        same(flag([a copy] == a), flag([b copy] == b), [what stringByAppendingString:@": copies to itself"]);
    }
    for (NSString *format in @[ @"%u more notifications", @"" ]) {
        id a = make_summary(ourCategory, ourActions, @"Hidden", format, 3);
        id b = make_summary(theirCategory, theirActions, @"Hidden", format, 3);
        NSString *what = [NSString stringWithFormat:@"a category with the summary format %@", format];
        same(call(a, @selector(hiddenPreviewsBodyPlaceholder)), call(b, @selector(hiddenPreviewsBodyPlaceholder)), [what stringByAppendingString:@": placeholder"]);
        same(call(a, @selector(categorySummaryFormat)), call(b, @selector(categorySummaryFormat)), [what stringByAppendingString:@": summary format"]);
    }
    same(call(make_hidden(ourCategory, ourActions, nil, 0), @selector(hiddenPreviewsBodyPlaceholder)), call(make_hidden(theirCategory, theirActions, nil, 0), @selector(hiddenPreviewsBodyPlaceholder)), @"a nil placeholder");
    same(call(make_summary(ourCategory, ourActions, @"h", nil, 0), @selector(categorySummaryFormat)), call(make_summary(theirCategory, theirActions, @"h", nil, 0), @selector(categorySummaryFormat)), @"a nil summary format");
    same(raised(^{ make_hidden(ourCategory, ourActions, @"h", 0); }), raised(^{ make_hidden(theirCategory, theirActions, @"h", 0); }), @"a hidden category is made");
    same(flag([make_hidden(ourCategory, ourActions, @"a", 0) isEqual:make_hidden(ourCategory, ourActions, @"a", 0)]),
         flag([make_hidden(theirCategory, theirActions, @"a", 0) isEqual:make_hidden(theirCategory, theirActions, @"a", 0)]), @"hidden categories alike");
    same(flag([make_hidden(ourCategory, ourActions, @"a", 0) isEqual:make_hidden(ourCategory, ourActions, @"b", 0)]),
         flag([make_hidden(theirCategory, theirActions, @"a", 0) isEqual:make_hidden(theirCategory, theirActions, @"b", 0)]), @"hidden categories differing by placeholder");
}

static void compare_actions(void)
{
    Class ourAction = ours([UNNotificationAction class]), theirAction = [UNNotificationAction class];
    Class ourText = ours([UNTextInputNotificationAction class]), theirText = [UNTextInputNotificationAction class];
    Class ourCategory = ours([UNNotificationCategory class]), theirCategory = [UNNotificationCategory class];
    for (NSNumber *options in @[ @0, @1, @2, @4, @7 ]) {
        NSUInteger o = options.unsignedIntegerValue;
        id a = make_action(ourAction, @"id", @"Title", o);
        UNNotificationAction *b = make_action(theirAction, @"id", @"Title", o);
        NSString *what = [NSString stringWithFormat:@"an action with options %lu", (unsigned long)o];
        same(call(a, @selector(identifier)), b.identifier, [what stringByAppendingString:@": identifier"]);
        same(call(a, @selector(title)), b.title, [what stringByAppendingString:@": title"]);
        same(@(((NSUInteger (*)(id, SEL))objc_msgSend)(a, @selector(options))), @(b.options), [what stringByAppendingString:@": options"]);
        same(tail([a description]), tail(b.description), [what stringByAppendingString:@": description"]);
        same(flag([a isEqual:make_action(ourAction, @"id", @"Title", o)]), flag([b isEqual:make_action(theirAction, @"id", @"Title", o)]),
             [what stringByAppendingString:@": equal to its twin"]);
        same(flag([a isEqual:make_action(ourAction, @"id", @"Other", o)]), flag([b isEqual:make_action(theirAction, @"id", @"Other", o)]),
             [what stringByAppendingString:@": equal to another title"]);
        same(flag([a hash] == [make_action(ourAction, @"id", @"Title", o) hash]), flag(b.hash == [make_action(theirAction, @"id", @"Title", o) hash]),
             [what stringByAppendingString:@": hash of its twin"]);
    }
    same(flag([make_action(ourAction, @"a", @"t", 0) isEqual:make_action(ourAction, @"a", @"t", 1)]),
         flag([make_action(theirAction, @"a", @"t", 0) isEqual:make_action(theirAction, @"a", @"t", 1)]), @"actions differing by options");
    same(raised(^{ make_action(ourAction, nil, @"t", 0); }), raised(^{ make_action(theirAction, nil, @"t", 0); }), @"an action with no identifier");
    same(raised(^{ make_action(ourAction, @"a", nil, 0); }), raised(^{ make_action(theirAction, @"a", nil, 0); }), @"an action with no title");
    same(flag([ourAction supportsSecureCoding]), flag([theirAction supportsSecureCoding]), @"an action's secure coding");
    same(flag([make_action(ourAction, @"a", @"t", 0) copy] != nil), @"YES", @"an action copies");
    id action = make_action(ourAction, @"a", @"t", 3);
    id copy = [action copy];
    same(flag(copy == action), flag(({ id x = make_action(theirAction, @"a", @"t", 3); [x copy] == x; })), @"an immutable action copies to itself");
    same(tail([round_trip(action, ourAction, @"UNNotificationAction") description]),
         tail([round_trip(make_action(theirAction, @"a", @"t", 3), nil, nil) description]), @"an archived action");

    id ta = make_text_action(ourText, @"t", @"Reply", 1, @"Send", @"Say");
    UNTextInputNotificationAction *tb = make_text_action(theirText, @"t", @"Reply", 1, @"Send", @"Say");
    same(call(ta, @selector(textInputButtonTitle)), tb.textInputButtonTitle, @"a text action's button");
    same(call(ta, @selector(textInputPlaceholder)), tb.textInputPlaceholder, @"a text action's placeholder");
    same(tail([ta description]), tail(tb.description), @"a text action's description");
    same(flag([ta isEqual:make_text_action(ourText, @"t", @"Reply", 1, @"Send", @"Say")]),
         flag([tb isEqual:make_text_action(theirText, @"t", @"Reply", 1, @"Send", @"Say")]), @"text actions alike");
    same(flag([ta isEqual:make_text_action(ourText, @"t", @"Reply", 1, @"Go", @"Say")]),
         flag([tb isEqual:make_text_action(theirText, @"t", @"Reply", 1, @"Go", @"Say")]), @"text actions differing by button");

    NSArray *ourActions = @[ make_action(ourAction, @"a", @"A", 0), make_action(ourAction, @"b", @"B", 2) ];
    NSArray *theirActions = @[ make_action(theirAction, @"a", @"A", 0), make_action(theirAction, @"b", @"B", 2) ];
    for (NSNumber *options in @[ @0, @1, @2, @3 ]) {
        NSUInteger o = options.unsignedIntegerValue;
        id a = make_category(ourCategory, @"cat", ourActions, @[ @"i" ], o);
        UNNotificationCategory *b = make_category(theirCategory, @"cat", theirActions, @[ @"i" ], o);
        NSString *what = [NSString stringWithFormat:@"a category with options %lu", (unsigned long)o];
        same(call(a, @selector(identifier)), b.identifier, [what stringByAppendingString:@": identifier"]);
        same(@([call(a, @selector(actions)) count]), @(b.actions.count), [what stringByAppendingString:@": actions"]);
        same(call(a, @selector(intentIdentifiers)), b.intentIdentifiers, [what stringByAppendingString:@": intents"]);
        same(@(((NSUInteger (*)(id, SEL))objc_msgSend)(a, @selector(options))), @(b.options), [what stringByAppendingString:@": options"]);
        same(flag([a isEqual:make_category(ourCategory, @"cat", ourActions, @[ @"i" ], o)]),
             flag([b isEqual:make_category(theirCategory, @"cat", theirActions, @[ @"i" ], o)]), [what stringByAppendingString:@": equal to its twin"]);
    }
    same(flag([make_category(ourCategory, @"cat", ourActions, @[], 0) isEqual:make_category(ourCategory, @"dog", ourActions, @[], 0)]),
         flag([make_category(theirCategory, @"cat", theirActions, @[], 0) isEqual:make_category(theirCategory, @"dog", theirActions, @[], 0)]),
         @"categories differing by identifier");
    same(raised(^{ make_category(ourCategory, nil, @[], @[], 0); }), raised(^{ make_category(theirCategory, nil, @[], @[], 0); }),
         @"a category with no identifier");
    same(flag([ourCategory supportsSecureCoding]), flag([theirCategory supportsSecureCoding]), @"a category's secure coding");
    compare_hidden_previews(ourCategory, theirCategory, ourActions, theirActions);
}

// Every method a class declares of its own, its metaclass's instance methods apart: what is inherited
// is the superclass's business and is compared there.
static NSArray *own_methods(Class cls)
{
    NSMutableArray *found = [NSMutableArray array];
    unsigned count = 0;
    Method *methods = class_copyMethodList(cls, &count);
    for (unsigned index = 0; index < count; index++)
        [found addObject:NSStringFromSelector(method_getName(methods[index]))];
    free(methods);
    [found sortUsingSelector:@selector(compare:)];
    return found;
}

// What a class adds over its superclass, which is what a caller can reach that the base does not.
static NSArray *added_over_superclass(Class cls)
{
    Class parent = class_getSuperclass(cls);
    NSMutableArray *found = [NSMutableArray array];
    unsigned count = 0;
    Method *methods = class_copyMethodList(cls, &count);
    for (unsigned index = 0; index < count; index++) {
        SEL selector = method_getName(methods[index]);
        if (!class_getInstanceMethod(parent, selector))
            [found addObject:NSStringFromSelector(selector)];
    }
    free(methods);
    [found sortUsingSelector:@selector(compare:)];
    return found;
}

// UNPushNotificationTrigger is a marker in both: no SDK this port is compiled against declares a
// member on it, so what a caller reads off it comes from UNNotificationTrigger and nothing is added.
// The system will not hand one over - only a request that arrived from a server carries one - so
// this compares the shape of the two classes and what the port's own trigger answers.
static void compare_push_triggers(void)
{
    Class theirClass = [UNPushNotificationTrigger class];
    if (!theirClass) {
        printf("FAIL this framework has no UNPushNotificationTrigger\n");
        failures++;
        return;
    }
    Class myClass = ours(theirClass);
    if (!myClass) {
        printf("FAIL the backport defines no UNPushNotificationTrigger\n");
        failures++;
        return;
    }
    same(plain(NSStringFromClass(myClass)), @"UNPushNotificationTrigger", @"the push trigger's name");
    same(plain(NSStringFromClass(class_getSuperclass(myClass))), plain(NSStringFromClass(ours([UNNotificationTrigger class]))),
         @"a push trigger is the backport's own notification trigger");
    same(plain(NSStringFromClass(class_getSuperclass(theirClass))), plain(NSStringFromClass([UNNotificationTrigger class])),
         @"a push trigger is a notification trigger");
    // Nothing is added over the base, since no header declares a member. The framework's class does
    // implement five of the base's members itself and, on the newest release, three more that no
    // header declares; those are its own business, so they are named rather than compared.
    same(added_over_superclass(myClass), @[], @"the backport's push trigger adds no member over its base");
    printf("note: this framework's UNPushNotificationTrigger declares %s\n",
           [[own_methods(theirClass) componentsJoinedByString:@" "] UTF8String]);

    id mine = ((id (*)(id, SEL))objc_msgSend)(myClass, @selector(charon_pushTrigger));
    checks++;
    if (![mine isKindOfClass:myClass] || [mine repeats])
        fail(@"a push trigger of the backport is a %@ that repeats %@", NSStringFromClass([mine class]), flag([mine repeats]));
    same(round_trip(mine, myClass, @"UNPushNotificationTrigger"), mine, @"a push trigger archived");
    checks++;
    if ([[mine copy] isEqual:mine] != YES)
        fail(@"a push trigger's copy is not equal to it");
}

int main(int argc, char *argv[])
{
    @autoreleasepool {
        if (argc > 1 && !strcmp(argv[1], "--expectations")) {
            write_expectations();
            return 0;
        }
        if (!ours([UNNotificationContent class])) {
            printf("FAIL the backport defines no UNNotificationContent\n");
            return 1;
        }
        compare_triggers();
        compare_matching();
        compare_content();
        compare_requests();
        compare_actions();
        compare_push_triggers();
        printf("%d checks, %d failures\n", checks, failures);
    }
    return failures;
}
