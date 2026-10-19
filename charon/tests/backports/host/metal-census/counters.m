/* The 21 string constants of the 14.0 band, compared BYTE FOR BYTE against Apple's own constants.
 *
 * APPLE'S COPY IS READ WITH dlsym, NOT BY NAMING IT. If the case declared the twenty-one externs
 * and read them, the link would bind each name to whichever definition won - the port's or Apple's -
 * and a port that defined all twenty-one wrongly would be compared with itself and pass. So the case
 * opens Apple's Metal by path, dlsyms each name THERE, and reads the bytes of what it finds; the
 * port's value is read from the port's own definition. Two independent answers, compared.
 *
 * THREE ANSWERS ARE DISTINGUISHED, because two of them look alike in a boolean:
 *   - a name that is NOT THERE: dlsym returns NULL, and a planted name that does not exist proves
 *     the lookup can say so;
 *   - a name that IS there and holds NULL;
 *   - a name that is there and holds a string, whose LENGTH and BYTES are then compared. A
 *     comparison of pointer identity, or of the text alone without the length, would pass a string
 *     that is a prefix of Apple's.
 *
 * NO DEVICE IS CREATED. These are strings; a device is not involved and MTLCreateSystemDefaultDevice
 * and a descriptor asks a device nothing (facts/Metal/DeviceOnThisMachine.md measures both).
 */
#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <string.h>

/* The port's own definitions, read from the object under test. */
extern NSString * const MTLCommonCounterTimestamp;
extern NSString * const MTLCommonCounterTessellationInputPatches;
extern NSString * const MTLCommonCounterVertexInvocations;
extern NSString * const MTLCommonCounterPostTessellationVertexInvocations;
extern NSString * const MTLCommonCounterClipperInvocations;
extern NSString * const MTLCommonCounterClipperPrimitivesOut;
extern NSString * const MTLCommonCounterFragmentInvocations;
extern NSString * const MTLCommonCounterFragmentsPassed;
extern NSString * const MTLCommonCounterComputeKernelInvocations;
extern NSString * const MTLCommonCounterTotalCycles;
extern NSString * const MTLCommonCounterVertexCycles;
extern NSString * const MTLCommonCounterTessellationCycles;
extern NSString * const MTLCommonCounterPostTessellationVertexCycles;
extern NSString * const MTLCommonCounterFragmentCycles;
extern NSString * const MTLCommonCounterRenderTargetWriteCycles;
extern NSString * const MTLCommonCounterSetTimestamp;
extern NSString * const MTLCommonCounterSetStageUtilization;
extern NSString * const MTLCommonCounterSetStatistic;
extern NSString * const MTLCounterErrorDomain;
extern NSString * const MTLBinaryArchiveDomain;
extern NSString * const MTLDynamicLibraryDomain;

static int failures;
static int checks;

static void check(BOOL ok, NSString *what)
{
    checks++;
    if (ok) { printf("  ok   %s\n", [what UTF8String]); }
    else { printf("  FAIL %s\n", [what UTF8String]); failures++; }
}

/* $1 the symbol name, $2 the port's value. Reads APPLE'S by that name, from Apple's own Metal. */
static void same_bytes(void *apple_metal, const char *name, NSString *port)
{
    void *sym = dlsym(apple_metal, name);
    if (sym == NULL) {
        /* NOT A MISSING-VALUE CASE: the symbol is absent from Apple's Metal entirely. */
        check(NO, ([NSString stringWithFormat:@"%s: the symbol is not in Apple's Metal at all", name]));
        return;
    }
    NSString * const apple = *(NSString * const *)sym;
    if (apple == NULL) {
        check(NO, ([NSString stringWithFormat:@"%s: Apple's symbol is there and holds NULL, which is "
                                          @"not the same as being absent", name]));
        return;
    }
    if (port == nil) {
        check(NO, ([NSString stringWithFormat:@"%s: the port holds NULL where Apple's holds \"%s\"",
                                          name, [apple UTF8String]]));
        return;
    }
    const char *a = [apple UTF8String];
    const char *p = [port UTF8String];
    size_t alen = (a && p) ? strlen(a) : 0, plen = (a && p) ? strlen(p) : 0;
    BOOL same = (a != NULL && p != NULL && alen == plen && memcmp(a, p, alen) == 0);
    check(same, ([NSString stringWithFormat:@"%s: \"%s\" (%zu bytes) is byte for byte Apple's own "
                                            @"\"%s\" (%zu bytes)", name,
                                             p ? p : "", plen, a ? a : "", alen]));
}

int main(void)
{
    @autoreleasepool {
        /* APPLE'S METAL, BY PATH. RTLD_NOLOAD first so the already-present one is used, and a plain
         * load if the process has not brought it in. Either way the handle is Apple's, and dlsym on
         * it cannot find the port's definitions. */
        void *apple_metal = dlopen("/System/Library/Frameworks/Metal.framework/Metal",
                                   RTLD_LAZY | RTLD_NOLOAD);
        if (apple_metal == NULL) {
            apple_metal = dlopen("/System/Library/Frameworks/Metal.framework/Metal", RTLD_LAZY);
        }
        if (apple_metal == NULL) {
            check(NO, @"Apple's Metal could not be opened, so no constant can be compared");
            printf("%d failure(s)\n", failures);
            return 1;
        }

        /* THE PLANTED MISSING-NAME CONTROL, first: a name that does not exist must read NULL, and
         * that has to be shown BEFORE the twenty-one comparisons, or "NULL" below proves nothing. */
        void *planted = dlsym(apple_metal, "MTLCommonCounterNoSuchNamePlantedForTheControl");
        check(planted == NULL,
              @"the planted control: a name Apple's Metal does not have reads NULL, so a NULL below "
              @"means a missing VALUE and not a missing NAME");
        void *empty = dlsym(apple_metal, "MTLBinaryArchiveDomain");
        check(empty != NULL,
              @"and a name it does have does not read NULL, so the two are told apart");

        same_bytes(apple_metal, "MTLCommonCounterTimestamp", MTLCommonCounterTimestamp);
        same_bytes(apple_metal, "MTLCommonCounterTessellationInputPatches", MTLCommonCounterTessellationInputPatches);
        same_bytes(apple_metal, "MTLCommonCounterVertexInvocations", MTLCommonCounterVertexInvocations);
        same_bytes(apple_metal, "MTLCommonCounterPostTessellationVertexInvocations", MTLCommonCounterPostTessellationVertexInvocations);
        same_bytes(apple_metal, "MTLCommonCounterClipperInvocations", MTLCommonCounterClipperInvocations);
        same_bytes(apple_metal, "MTLCommonCounterClipperPrimitivesOut", MTLCommonCounterClipperPrimitivesOut);
        same_bytes(apple_metal, "MTLCommonCounterFragmentInvocations", MTLCommonCounterFragmentInvocations);
        same_bytes(apple_metal, "MTLCommonCounterFragmentsPassed", MTLCommonCounterFragmentsPassed);
        same_bytes(apple_metal, "MTLCommonCounterComputeKernelInvocations", MTLCommonCounterComputeKernelInvocations);
        same_bytes(apple_metal, "MTLCommonCounterTotalCycles", MTLCommonCounterTotalCycles);
        same_bytes(apple_metal, "MTLCommonCounterVertexCycles", MTLCommonCounterVertexCycles);
        same_bytes(apple_metal, "MTLCommonCounterTessellationCycles", MTLCommonCounterTessellationCycles);
        same_bytes(apple_metal, "MTLCommonCounterPostTessellationVertexCycles", MTLCommonCounterPostTessellationVertexCycles);
        same_bytes(apple_metal, "MTLCommonCounterFragmentCycles", MTLCommonCounterFragmentCycles);
        same_bytes(apple_metal, "MTLCommonCounterRenderTargetWriteCycles", MTLCommonCounterRenderTargetWriteCycles);
        same_bytes(apple_metal, "MTLCommonCounterSetTimestamp", MTLCommonCounterSetTimestamp);
        same_bytes(apple_metal, "MTLCommonCounterSetStageUtilization", MTLCommonCounterSetStageUtilization);
        same_bytes(apple_metal, "MTLCommonCounterSetStatistic", MTLCommonCounterSetStatistic);
        same_bytes(apple_metal, "MTLCounterErrorDomain", MTLCounterErrorDomain);
        same_bytes(apple_metal, "MTLBinaryArchiveDomain", MTLBinaryArchiveDomain);
        same_bytes(apple_metal, "MTLDynamicLibraryDomain", MTLDynamicLibraryDomain);

        printf("no device was created: %d checks, every constant read from Apple's own Metal by name\n",
               checks);
    }
    if (failures) { printf("%d failure(s)\n", failures); return 1; }
    printf("all checks passed\n");
    return 0;
}
