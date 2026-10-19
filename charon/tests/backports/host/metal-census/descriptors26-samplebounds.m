/* descriptors26-samplebounds.m - the sample-position bounds, ONE BOUND PER INVOCATION and ONE SIDE PER
 * INVOCATION, because a bound Metal refuses is an ASSERTION and an assertion stops the process.
 *
 *     descriptors26-samplebounds.m <bound> apple|port
 *
 * That is the whole reason this is its own case and its own binary. Each line below is a CAPTURED
 * stderr line, one invocation per bound, with the framework's own line numbers - they are what the
 * harness compares the shape against, and the facts page quotes them character for character:
 *
 *   count            -[MTL4RenderPassDescriptor setSamplePositions:count:]:417: failed assertion
 *                     `count (3) is not a supported sample count for custom positions. count must be 0,
 *                      2, 4 or 8.'
 *   coordinates      -[MTL4RenderPassDescriptor setSamplePositions:count:]:433: failed assertion
 *                     `Provided sample position x-coodicate (1.500000) at index 1 is not within the
 *                      range [0,1).'
 *   coordinates-below the y axis has its OWN assertion, at line 435, not the same one - measured
 *                     separately, and "coodicate" is Apple's spelling in both.
 *   read-smaller     -[MTL4RenderPassDescriptor getSamplePositions:count:]:449: failed assertion
 *                     `Non-zero count (2) does not match the number of programmed custom sample
 *                      positions (4).'
 *   read-larger      the same assertion, with 8 instead of 2 - a count SMALLER than the programmed one
 *                     is refused exactly as a larger one is, which is the case the in-process comparison
 *                     cannot ask.
 *   read-zero        asserts nothing, and answers the programmed count on both sides.
 *
 * The PORT's side of each is an NSException, so it is catchable and this case prints what it said. The
 * harness runs each bound twice - once per side - and requires: the port prints "refused, " and exits
 * 0, and Apple's side does NOT print "accepted" and does not exit 0. An assertion's text is in the
 * script's own comments rather than parsed out of a signal: what is checked is the SHAPE both sides
 * agree on, which is the thing a caller can rely on.
 */
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <objc/message.h>

int main(int argc, const char **argv)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        const char *bound = argc > 1 ? argv[1] : "";
        BOOL port = argc > 2 && strcmp(argv[2], "port") == 0;
        const char *side = port ? "port" : "apple";
        printf("%s: bound %s\n", side, bound);

        Class klass = NSClassFromString(port ? @"charonHost_MTL4RenderPassDescriptor" : @"MTL4RenderPassDescriptor");
        if (!klass) {
            printf("%s: no class of that name\n", side);
            return 2;
        }
        id pass = [[klass alloc] init];
        void (*setPositions)(id, SEL, const MTLSamplePosition *, NSUInteger) =
            (void (*)(id, SEL, const MTLSamplePosition *, NSUInteger))objc_msgSend;
        unsigned long (*getPositions)(id, SEL, MTLSamplePosition *, NSUInteger) =
            (unsigned long (*)(id, SEL, MTLSamplePosition *, NSUInteger))objc_msgSend;

        /* FOUR POSITIONS PROGRAMMED, all inside [0, 1) - so the only thing any case below breaks is
         * the bound it names. */
        MTLSamplePosition four[4];
        for (unsigned i = 0; i < 4; i++) { four[i].x = 0.125f * (i + 1); four[i].y = 0.0625f * (i + 1); }
        setPositions(pass, @selector(setSamplePositions:count:), four, 4);
        printf("%s: four positions programmed\n", side);

        if (strcmp(bound, "count") == 0) {
            @try { setPositions(pass, @selector(setSamplePositions:count:), four, 3);
                   printf("%s: accepted a count of 3\n", side); }
            @catch (NSException *why) { printf("%s: refused, %s\n", side, [[why reason] UTF8String]); }
        } else if (strcmp(bound, "coordinates") == 0) {
            MTLSamplePosition bad[4];
            memcpy(bad, four, sizeof(bad));
            bad[1].x = 1.5f;                    /* above the top of [0, 1) */
            @try { setPositions(pass, @selector(setSamplePositions:count:), bad, 4);
                   printf("%s: accepted an x of 1.5\n", side); }
            @catch (NSException *why) { printf("%s: refused, %s\n", side, [[why reason] UTF8String]); }
        } else if (strcmp(bound, "coordinates-below") == 0) {
            MTLSamplePosition bad[4];
            memcpy(bad, four, sizeof(bad));
            bad[2].y = -0.5f;                   /* below the bottom of [0, 1) */
            @try { setPositions(pass, @selector(setSamplePositions:count:), bad, 4);
                   printf("%s: accepted a y of -0.5\n", side); }
            @catch (NSException *why) { printf("%s: refused, %s\n", side, [[why reason] UTF8String]); }
        } else if (strcmp(bound, "read-smaller") == 0) {
            MTLSamplePosition out[8];
            memset(out, 0, sizeof(out));
            @try { unsigned long got = getPositions(pass, @selector(getSamplePositions:count:), out, 2);
                   printf("%s: accepted a read of count 2 and answered %lu\n", side, got); }
            @catch (NSException *why) { printf("%s: refused, %s\n", side, [[why reason] UTF8String]); }
        } else if (strcmp(bound, "read-larger") == 0) {
            MTLSamplePosition out[8];
            memset(out, 0, sizeof(out));
            @try { unsigned long got = getPositions(pass, @selector(getSamplePositions:count:), out, 8);
                   printf("%s: accepted a read of count 8 and answered %lu\n", side, got); }
            @catch (NSException *why) { printf("%s: refused, %s\n", side, [[why reason] UTF8String]); }
        } else if (strcmp(bound, "read-zero") == 0) {
            /* THE COUNT THAT IS ALWAYS ALLOWED, and the one a caller uses to ask how many there are:
             * measured, a read of count 0 answers the programmed count and asserts nothing. */
            MTLSamplePosition out[8];
            memset(out, 0, sizeof(out));
            @try { unsigned long got = getPositions(pass, @selector(getSamplePositions:count:), out, 0);
                   printf("%s: accepted a read of count 0 and answered %lu\n", side, got); }
            @catch (NSException *why) { printf("%s: refused, %s\n", side, [[why reason] UTF8String]); }
        } else {
            printf("%s: no such bound\n", side);
            return 2;
        }
    }
    return 0;
}