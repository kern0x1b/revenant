#import "hover16_scenario.h"

void revenant_windowed_run(UIWindow *window)
{
    @autoreleasepool {
        h16_port_mode = YES;
        NSString *expected = [NSString stringWithContentsOfFile:[NSString stringWithUTF8String:getenv("REVENANT_EXPECTED")] encoding:NSUTF8StringEncoding error:NULL];
        UIView *host = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 200, 100)];
        [window addSubview:host];
        UISearchBar *bar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 120, 200, 44)];
        [window addSubview:bar];
        UITextField *field = nil;
        for (UIView *sub in bar.subviews)
            if ([sub isKindOfClass:[UITextField class]])
                field = (UITextField *)sub;

        Class hover = h16_class([UIHoverGestureRecognizer class], "UIHoverGestureRecognizer");
        NSArray *recorded_ours = hover16_scenario(hover, host, bar, field), *recorded_theirs = [expected componentsSeparatedByString:@"\n"];
        NSMutableArray *carried_ours = [NSMutableArray array], *carried_theirs = [NSMutableArray array];
        for (NSUInteger index = 0; index < MAX(recorded_ours.count, recorded_theirs.count); index++) {
            NSString *a = index < recorded_ours.count ? recorded_ours[index] : @"<none>", *b = index < recorded_theirs.count ? recorded_theirs[index] : @"<none>";
            if ([a hasPrefix:@"release "] || [b hasPrefix:@"release "])
                continue;
            [carried_ours addObject:a];
            [carried_theirs addObject:b];
        }
        ur_agree(@"the four members of the hover recogniser that iOS 16.1 and 16.4 added, and UITextInputContext", carried_ours, carried_theirs);
        revenant_check([recorded_ours containsObject:@"release respondsrollAngle 0"] && [recorded_theirs containsObject:@"release respondsrollAngle 1"],
                     "rollAngle of 17.5 stays with the release: it answers it and the port does not",
                     ([NSString stringWithFormat:@"port %@ system %@", [recorded_ours containsObject:@"release respondsrollAngle 0"] ? @"answers" : @"does not",
                                                                     [recorded_theirs containsObject:@"release respondsrollAngle 1"] ? @"answers" : @"does not"]));

        revenant_check(!class_getInstanceMethod([bar class], NSSelectorFromString(@"revenantHostIsEnabled")) &&
                         !class_getInstanceMethod([bar class], NSSelectorFromString(@"revenantHostSetEnabled:")) && [bar respondsToSelector:NSSelectorFromString(@"isEnabled")],
                     "the port leaves UISearchBar's enabled to the release's own accessors", @"the port answers it");

        BOOL (^empty)(UIHoverGestureRecognizer *, UIView *) = ^BOOL(UIHoverGestureRecognizer *recognizer, UIView *in) {
            CGVector vector = [recognizer azimuthUnitVectorInView:in];
            return vector.dx == 0 && vector.dy == 0;
        };
        BOOL (^documented)(UIHoverGestureRecognizer *, UIView *) = ^BOOL(UIHoverGestureRecognizer *recognizer, UIView *in) {
            return recognizer.zOffset == 0 && recognizer.altitudeAngle == 0 && [recognizer azimuthAngleInView:in] == 0 && [recognizer azimuthAngleInView:nil] == 0 &&
                   empty(recognizer, in) && empty(recognizer, nil);
        };
        UIHoverGestureRecognizer *theirs = [[UIHoverGestureRecognizer alloc] initWithTarget:nil action:NULL];
        revenant_check(documented(theirs, host), "the system answers 0 and an empty vector for a device that cannot hover",
                     ([NSString stringWithFormat:@"%g %g %g %@", theirs.zOffset, theirs.altitudeAngle, [theirs azimuthAngleInView:host],
                                            h16_vector([theirs azimuthUnitVectorInView:host])]));
        UIHoverGestureRecognizer *ours = (UIHoverGestureRecognizer *)[[hover alloc] initWithTarget:nil action:NULL];
        revenant_check(documented(ours, host), "and so does the port's own recogniser",
                     ([NSString stringWithFormat:@"%g %g %g %@", ours.zOffset, ours.altitudeAngle, [ours azimuthAngleInView:host],
                                            h16_vector([ours azimuthUnitVectorInView:host])]));
    }
}
