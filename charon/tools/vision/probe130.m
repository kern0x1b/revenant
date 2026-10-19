// The 13.0 API this slice carries, measured against the system's own Vision: which image each
// answer comes from, the truth table of +revision:supportsConstellation:, what VNElementTypeSize
// answers for every argument, the two animal identifiers' values, whether the progress protocol is
// reachable by name, and each request's own revision table. A name this Vision does not carry is the
// control: a reader that cannot find one cannot read a zero.
#import <Foundation/Foundation.h>
#import <Vision/Vision.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#include <string.h>

static const char *image_of(const void *symbol)
{
    static Dl_info info;
    if (symbol && dladdr(symbol, &info) && info.dli_fname) {
        const char *mark = strrchr(info.dli_fname, '/');
        return mark ? mark + 1 : info.dli_fname;
    }
    return "(no dladdr)";
}

static const char *yesno(BOOL answer) { return answer ? "YES" : "NO"; }

int main(void)
{
    printf("VNElementTypeSize from: %s\n", image_of((const void *)VNElementTypeSize));
    printf("+[VNDetectFaceLandmarksRequest class] from: %s\n",
           image_of((__bridge const void *)[VNDetectFaceLandmarksRequest class]));
    printf("&VNAnimalIdentifierCat from: %s\n", image_of(&VNAnimalIdentifierCat));

    for (NSUInteger revision = 1; revision <= 4; revision++)
        for (NSUInteger constellation = 0; constellation <= 2; constellation++)
            printf("revision %lu supports constellation %lu: %s\n", (unsigned long)revision,
                   (unsigned long)constellation,
                   yesno([VNDetectFaceLandmarksRequest revision:revision
                                    supportsConstellation:(VNRequestFaceLandmarksConstellation)constellation]));

    for (NSUInteger value = 0; value < 5; value++)
        printf("VNElementTypeSize(%lu) = %lu\n", (unsigned long)value,
               (unsigned long)VNElementTypeSize((VNElementType)value));

    printf("VNAnimalIdentifierCat = %s\n", VNAnimalIdentifierCat.UTF8String);
    printf("VNAnimalIdentifierDog = %s\n", VNAnimalIdentifierDog.UTF8String);

    for (NSString *name in @[@"VNRequestProgressProviding", @"VNNoProtocolOfThisName"])
        printf("NSProtocolFromString(%s) = %s\n", name.UTF8String,
               NSProtocolFromString(name) ? "found" : "nil");

    for (NSString *name in @[@"VNClassifyImageRequest", @"VNRecognizeAnimalsRequest", @"VNRecognizeTextRequest",
                             @"VNDetectHumanRectanglesRequest", @"VNRecognizedText", @"VNRecognizedTextObservation",
                             @"VNFeaturePrintObservation", @"VNSaliencyImageObservation",
                             @"VNGenerateAttentionBasedSaliencyImageRequest",
                             @"VNGenerateObjectnessBasedSaliencyImageRequest",
                             @"VNGenerateImageFeaturePrintRequest", @"VNDetectFaceCaptureQualityRequest",
                             @"VNNoClassOfThisName"])
        printf("NSClassFromString(%s) = %s\n", name.UTF8String,
               NSClassFromString(name) ? "found" : "nil");

    VNRecognizeTextRequest *text = [[VNRecognizeTextRequest alloc] init];
    printf("VNRecognizeTextRequest conformsToProtocol(VNRequestProgressProviding) = %s\n",
           yesno([text conformsToProtocol:@protocol(VNRequestProgressProviding)]));
    printf("VNRecognizeTextRequest indeterminate = %s\n", yesno(text.indeterminate));

    // The three methods these three observation classes declare over NSObject or themselves, asked
    // of a fresh instance of each: what a class with nothing in it answers. The port's objects of
    // the same three classes are held to the same records by tools/vision/conforms130.m.
    {
        VNRecognizedText *word = [[VNRecognizedText alloc] init];
        NSError *error = nil;
        VNRectangleObservation *box = [word boundingBoxForRange:NSMakeRange(0, 0) error:&error];
        printf("fresh VNRecognizedText boundingBoxForRange:{0,0} = %s, error = %s\n", box ? "a box" : "nil",
               error ? [NSString stringWithFormat:@"%@ %ld", error.domain, (long)error.code].UTF8String : "none");
        printf("fresh VNRecognizedText boundingBoxForRange responds: %s\n",
               [word respondsToSelector:@selector(boundingBoxForRange:error:)] ? "responds" : "no selector");

        VNRecognizedTextObservation *area = [[VNRecognizedTextObservation alloc] init];
        printf("fresh VNRecognizedTextObservation topCandidates:10 = %lu candidates, topCandidates:0 = %lu, responds: %s\n",
               (unsigned long)[[area topCandidates:10] count], (unsigned long)[[area topCandidates:0] count],
               [area respondsToSelector:@selector(topCandidates:)] ? "responds" : "no selector");

        VNFeaturePrintObservation *print_ = [[VNFeaturePrintObservation alloc] init];
        float distance = -1.0f;
        error = nil;
        BOOL comparable = [print_ computeDistance:&distance toFeaturePrintObservation:print_ error:&error];
        printf("fresh VNFeaturePrintObservation computeDistance to itself = %s, distance = %f, error = %s\n",
               yesno(comparable), (double)distance,
               error ? [NSString stringWithFormat:@"%@ %ld", error.domain, (long)error.code].UTF8String : "none");
        printf("fresh VNFeaturePrintObservation elementType = %lu elementCount = %lu data = %s, responds: %s\n",
               (unsigned long)print_.elementType, (unsigned long)print_.elementCount,
               print_.data ? "set" : "nil",
               ([print_ respondsToSelector:@selector(computeDistance:toFeaturePrintObservation:error:)]
                    ? "responds" : "no selector"));

        // The three selectors spelled as the runtime holds them, so that a "no selector" above can
        // be told apart from a spelling this host's Vision has moved on from.
        for (Class cls in @[[VNRecognizedText class], [VNRecognizedTextObservation class],
                            [VNFeaturePrintObservation class]]) {
            unsigned int count = 0;
            Method *methods = class_copyMethodList(cls, &count);
            printf("%s carries %u method(s):", class_getName(cls), count);
            for (unsigned int i = 0; i < count; i++) printf(" %s", sel_getName(method_getName(methods[i])));
            free(methods);
            printf("\n");
        }

        // Which of these five classes hands back an object from alloc/init at all. A class that
        // does not makes every question above a question to nil, and nil answers 0, NO and nil --
        // so this line is what tells a real answer from a nil one, and the name that is no class
        // is the control for the reader.
        for (Class cls in @[[VNRecognizedText class], [VNRecognizedTextObservation class],
                            [VNFeaturePrintObservation class], [VNSaliencyImageObservation class],
                            [VNRecognizeTextRequest class]]) {
            id fresh = [[cls alloc] init];
            printf("alloc/init %-34s %s\n", class_getName(cls), fresh ? "gave an object" : "GAVE NIL");
        }
        printf("alloc/init %-34s %s\n", "VNNoClassOfThisName (the control)",
               NSClassFromString(@"VNNoClassOfThisName") ? "found" : "no class, nil either way");

        // The three catalogue class methods these requests declare. Apple's own answers, so that
        // what the port answers for them can be read against a real one and not against a memory.
        for (NSUInteger revision = 1; revision <= 3; revision++) {
            error = nil;
            NSArray *classes = [VNClassifyImageRequest knownClassificationsForRevision:revision error:&error];
            printf("knownClassificationsForRevision:%lu = %lu name(s), error = %s\n", (unsigned long)revision,
                   (unsigned long)classes.count,
                   error ? [NSString stringWithFormat:@"%@ %ld", error.domain, (long)error.code].UTF8String : "none");
            // The list itself is thousands of names long and is not printed: the count is the whole
            // of what a port that carries no classifier can be compared against, and a reader who
            // wants the names asks Vision for them.
            if (classes.count)
                printf("    the first is \"%s\" and the last is \"%s\"\n",
                       [classes.firstObject identifier].UTF8String,
                       [classes.lastObject identifier].UTF8String);

            error = nil;
            NSArray *animals = [VNRecognizeAnimalsRequest knownAnimalIdentifiersForRevision:revision error:&error];
            printf("knownAnimalIdentifiersForRevision:%lu = %lu identifier(s), error = %s\n", (unsigned long)revision,
                   (unsigned long)animals.count,
                   error ? [NSString stringWithFormat:@"%@ %ld", error.domain, (long)error.code].UTF8String : "none");
            if (animals.count)
                printf("    they are %s\n",
                       [animals componentsJoinedByString:@","].UTF8String);

            error = nil;
            NSArray *languages = [VNRecognizeTextRequest supportedRecognitionLanguagesForTextRecognitionLevel:
                                                             VNRequestTextRecognitionLevelAccurate
                                                                  revision:revision error:&error];
            printf("supportedRecognitionLanguagesForTextRecognitionLevel:accurate revision:%lu = %lu language(s), error = %s\n",
                   (unsigned long)revision, (unsigned long)languages.count,
                   error ? [NSString stringWithFormat:@"%@ %ld", error.domain, (long)error.code].UTF8String : "none");
        }
    }

    for (Class cls in @[[VNRecognizeAnimalsRequest class], [VNClassifyImageRequest class],
                        [VNDetectHumanRectanglesRequest class], [VNDetectFaceCaptureQualityRequest class],
                        [VNGenerateAttentionBasedSaliencyImageRequest class],
                        [VNGenerateObjectnessBasedSaliencyImageRequest class],
                        [VNGenerateImageFeaturePrintRequest class], [VNRecognizeTextRequest class],
                        [VNDetectFaceLandmarksRequest class], [VNDetectRectanglesRequest class]]) {
        id request = [[cls alloc] init];
        printf("%-46s supportedRevisions = %-8s currentRevision = %lu revisionProviding = %s\n", class_getName(cls),
               [cls supportedRevisions].description.UTF8String, (unsigned long)[cls currentRevision],
               yesno([request conformsToProtocol:@protocol(VNRequestRevisionProviding)]));
    }
    return 0;
}
