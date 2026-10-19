// hover16_test.m - the six names of iOS 16.4 this band carries, read off the port and off the
// recording hover16_system.m made of the host. The two lists are compared line by line, and the
// contract Apple's own header states for a device without the capability is asserted beside it,
// because a comparison alone says only that the two agree - not that what they agree on is right.
#import "hover16_scenario.h"

void charon_windowed_run(UIWindow *window)
{
    @autoreleasepool {
        h16_port_mode = YES;
        NSString *expected = [NSString stringWithContentsOfFile:[NSString stringWithUTF8String:getenv("CHARON_EXPECTED")] encoding:NSUTF8StringEncoding error:NULL];
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
        // The lines marked `release ` are the ones this band does not carry - rollAngle of 17.5 - and
        // they are held out of the comparison and asserted apart, because the release answering a name
        // the port declines to is the answer and not a difference to reconcile.
        NSMutableArray *carried_ours = [NSMutableArray array], *carried_theirs = [NSMutableArray array];
        for (NSUInteger index = 0; index < MAX(recorded_ours.count, recorded_theirs.count); index++) {
            NSString *a = index < recorded_ours.count ? recorded_ours[index] : @"<none>", *b = index < recorded_theirs.count ? recorded_theirs[index] : @"<none>";
            if ([a hasPrefix:@"release "] || [b hasPrefix:@"release "])
                continue;
            [carried_ours addObject:a];
            [carried_theirs addObject:b];
        }
        ur_agree(@"the four members of the hover recogniser that iOS 16.1 and 16.4 added, and UITextInputContext", carried_ours, carried_theirs);
        charon_check([recorded_ours containsObject:@"release respondsrollAngle 0"] && [recorded_theirs containsObject:@"release respondsrollAngle 1"],
                     "rollAngle of 17.5 stays with the release: it answers it and the port does not",
                     ([NSString stringWithFormat:@"port %@ system %@", [recorded_ours containsObject:@"release respondsrollAngle 0"] ? @"answers" : @"does not",
                                                                     [recorded_theirs containsObject:@"release respondsrollAngle 1"] ? @"answers" : @"does not"]));

        // UISearchBar.enabled of 16.4 is the one name in this scenario the port does not carry, and the
        // scenario reads it through the release's own selectors in both modes so that the comparison is
        // of the release's answer. What is checked here is that the answer really is the release's: the
        // port's search bar is the release's search bar, and no Charon category adds these accessors.
        charon_check(!class_getInstanceMethod([bar class], NSSelectorFromString(@"charonHostIsEnabled")) &&
                         !class_getInstanceMethod([bar class], NSSelectorFromString(@"charonHostSetEnabled:")) && [bar respondsToSelector:NSSelectorFromString(@"isEnabled")],
                     "the port leaves UISearchBar's enabled to the release's own accessors", @"the port answers it");

        // The header of UIHoverGestureRecognizer in SDK 16.4 gives the fallback values for devices that lack each of z offset, azimuth and altitude: 0 for z offset,
        // an empty vector for azimuth, and 0 for altitude. The host is such a device - a Mac has no
        // hovering device - so these are the values the port has to answer, and they are asserted
        // here against the host's own class rather than against the port's, so the check does not
        // pass by comparing two wrong numbers.
        // CGGeometry declares no CGVectorEqualToVector, so an empty vector is compared by its halves.
        BOOL (^empty)(UIHoverGestureRecognizer *, UIView *) = ^BOOL(UIHoverGestureRecognizer *recognizer, UIView *in) {
            CGVector vector = [recognizer azimuthUnitVectorInView:in];
            return vector.dx == 0 && vector.dy == 0;
        };
        BOOL (^documented)(UIHoverGestureRecognizer *, UIView *) = ^BOOL(UIHoverGestureRecognizer *recognizer, UIView *in) {
            return recognizer.zOffset == 0 && recognizer.altitudeAngle == 0 && [recognizer azimuthAngleInView:in] == 0 && [recognizer azimuthAngleInView:nil] == 0 &&
                   empty(recognizer, in) && empty(recognizer, nil);
        };
        UIHoverGestureRecognizer *theirs = [[UIHoverGestureRecognizer alloc] initWithTarget:nil action:NULL];
        charon_check(documented(theirs, host), "the system answers 0 and an empty vector for a device that cannot hover",
                     ([NSString stringWithFormat:@"%g %g %g %@", theirs.zOffset, theirs.altitudeAngle, [theirs azimuthAngleInView:host],
                                            h16_vector([theirs azimuthUnitVectorInView:host])]));
        UIHoverGestureRecognizer *ours = (UIHoverGestureRecognizer *)[[hover alloc] initWithTarget:nil action:NULL];
        charon_check(documented(ours, host), "and so does the port's own recogniser",
                     ([NSString stringWithFormat:@"%g %g %g %@", ours.zOffset, ours.altitudeAngle, [ours azimuthAngleInView:host],
                                            h16_vector([ours azimuthUnitVectorInView:host])]));
    }
}
