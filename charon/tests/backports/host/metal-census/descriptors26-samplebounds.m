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
            bad[1].x = 1.5f;
            @try { setPositions(pass, @selector(setSamplePositions:count:), bad, 4);
                   printf("%s: accepted an x of 1.5\n", side); }
            @catch (NSException *why) { printf("%s: refused, %s\n", side, [[why reason] UTF8String]); }
        } else if (strcmp(bound, "coordinates-below") == 0) {
            MTLSamplePosition bad[4];
            memcpy(bad, four, sizeof(bad));
            bad[2].y = -0.5f;
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
