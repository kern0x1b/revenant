#import <Foundation/Foundation.h>
#import <Vision/Vision.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#include <string.h>

static const char *leaf(const char *path)
{
    const char *mark = strrchr(path, '/');
    return mark ? mark + 1 : path;
}

int main(void)
{
    static Dl_info info;
    for (Class cls in @[[VNDetectFaceCaptureQualityRequest class], [VNRecognizeTextRequest class],
                        [VNRecognizedText class], [VNDetectFaceLandmarksRequest class]]) {
        const char *image = "(no dladdr)";
        if (dladdr((__bridge const void *)cls, &info) && info.dli_fname) image = leaf(info.dli_fname);
        printf("%-46s %-22s conforms:", class_getName(cls), image);
        for (Protocol *p in @[@protocol(VNFaceObservationAccepting), @protocol(VNRequestProgressProviding),
                               @protocol(VNRequestRevisionProviding), @protocol(NSSecureCoding), @protocol(NSCopying)]) {
            if ([cls conformsToProtocol:p]) printf("  %s", protocol_getName(p));
        }
        printf("\n");
    }
    Class ghost = NSClassFromString(@"VNNoClassOfThisName");
    printf("%-46s %-22s conforms to nothing: %s\n", "VNNoClassOfThisName (the control)", ghost ? "found" : "nil class",
           [ghost conformsToProtocol:@protocol(VNRequestProgressProviding)] ? "YES" : "no");

    VNRecognizeTextRequest *text = [[VNRecognizeTextRequest alloc] init];
    printf("\nVNRecognizeTextRequest progressHandler responds: %s, indeterminate = %s, usesLanguageCorrection = %s\n",
           [text respondsToSelector:@selector(progressHandler)] ? "responds" : "no selector",
           text.indeterminate ? "YES" : "NO", text.usesLanguageCorrection ? "YES" : "NO");
    VNRecognizedText *word = [[VNRecognizedText alloc] init];
    printf("VNRecognizedText supportsSecureCoding = %s, string = %s, confidence = %f, requestRevision = %lu\n",
           [VNRecognizedText supportsSecureCoding] ? "YES" : "NO",
           word.string ? "set" : "nil", (double)word.confidence, (unsigned long)word.requestRevision);
    printf("VNDetectHumanRectanglesRequest upperBodyOnly = %s\n",
           [[[VNDetectHumanRectanglesRequest alloc] init] upperBodyOnly] ? "YES" : "NO");
    printf("VNGenerateImageFeaturePrintRequest imageCropAndScaleOption = %lu (ScaleFill is 2, CenterCrop is 0)\n",
           (unsigned long)[[[VNGenerateImageFeaturePrintRequest alloc] init] imageCropAndScaleOption]);

    {
        NSError *error = nil;
        NSArray *animals = [VNRecognizeAnimalsRequest knownAnimalIdentifiersForRevision:1 error:&error];
        printf("VNRecognizeAnimalsRequest knownAnimalIdentifiersForRevision:1 = %s, error = %s\n",
               [[animals componentsJoinedByString:@","] UTF8String] ?: "nil",
               error ? "an error" : "none");
        error = nil;
        animals = [VNRecognizeAnimalsRequest knownAnimalIdentifiersForRevision:3 error:&error];
        printf("VNRecognizeAnimalsRequest knownAnimalIdentifiersForRevision:3 = %s, error = %s\n",
               animals ? "a list" : "nil", error ? [NSString stringWithFormat:@"%@ %ld", error.domain,
                                                                            (long)error.code].UTF8String
                                                  : "none");

        VNRecognizedText *word = [[VNRecognizedText alloc] init];
        error = nil;
        VNRectangleObservation *box = [word boundingBoxForRange:NSMakeRange(0, 0) error:&error];
        printf("VNRecognizedText boundingBoxForRange:{0,0} = %s, error = %s, responds: %s\n", box ? "a box" : "nil",
               error ? "an error" : "none",
               [word respondsToSelector:@selector(boundingBoxForRange:error:)] ? "responds" : "no selector");

        VNRecognizedTextObservation *area = [[VNRecognizedTextObservation alloc] init];
        printf("VNRecognizedTextObservation topCandidates:10 = %lu candidate(s), responds: %s\n",
               (unsigned long)[[area topCandidates:10] count],
               [area respondsToSelector:@selector(topCandidates:)] ? "responds" : "no selector");

        VNFeaturePrintObservation *featurePrint = [[VNFeaturePrintObservation alloc] init];
        float distance = -1.0f;
        error = nil;
        BOOL compared = [featurePrint computeDistance:&distance toFeaturePrintObservation:featurePrint error:&error];
        printf("VNFeaturePrintObservation computeDistance to itself = %s, distance left = %f, error = %s, responds: %s\n",
               compared ? "YES" : "NO", (double)distance, error ? "an error" : "none",
               [featurePrint respondsToSelector:@selector(computeDistance:toFeaturePrintObservation:error:)]
                   ? "responds" : "no selector");

        struct { const char *class; const char *selector; } missing[] = {
            {"VNClassifyImageRequest", "knownClassificationsForRevision:error:"},
            {"VNRecognizeAnimalsRequest", "supportedIdentifiersAndReturnError:"},
            {"VNRecognizeTextRequest", "supportedRecognitionLanguagesForTextRecognitionLevel:revision:error:"},
        };
        for (unsigned i = 0; i < sizeof(missing) / sizeof(missing[0]); i++) {
            Class cls = NSClassFromString([NSString stringWithFormat:@"Charon%s", missing[i].class]);
            printf("%-34s +%-58s answered: %s\n", missing[i].class, missing[i].selector,
                   cls && [cls instancesRespondToSelector:NSSelectorFromString([NSString stringWithUTF8String:missing[i].selector])]
                       ? "yes" : "no, a caller sending it gets an unrecognised selector");
        }
    }
    return 0;
}
