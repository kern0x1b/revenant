#import <Foundation/Foundation.h>
#import "vtclass-cases.h"
#import <objc/runtime.h>

#define VTCLASS_STR_(x) #x
#define VTCLASS_STR(x) VTCLASS_STR_(x)
#define VTCLASS_NAME(x) VTCLASS_STR(x)

typedef struct {
    const char *name;
    const char *protocol;
    const char *classProperties;
    const char *instanceProperties;
} VTClassShape;

static const VTClassShape vtClassShapes[] = {
    {"VTFrameProcessor", "", "", ""},
    {"VTFrameProcessorFrame", "", "", "buffer presentationTimeStamp"},
    {"VTFrameProcessorOpticalFlow", "", "", "forwardFlow backwardFlow"},
    {"VTFrameRateConversionConfiguration", "VTFrameProcessorConfiguration", "supportedRevisions defaultRevision isSupported maximumDimensions minimumDimensions", "frameWidth frameHeight usePrecomputedFlow qualityPrioritization revision frameSupportedPixelFormats sourcePixelBufferAttributes destinationPixelBufferAttributes nextFrameCount previousFrameCount"},
    {"VTFrameRateConversionParameters", "VTFrameProcessorParameters", "", "nextFrame opticalFlow interpolationPhase submissionMode sourceFrame destinationFrame destinationFrames"},
    {"VTLowLatencyFrameInterpolationConfiguration", "VTFrameProcessorConfiguration", "isSupported maximumDimensions minimumDimensions", "frameWidth frameHeight spatialScaleFactor numberOfInterpolatedFrames frameSupportedPixelFormats sourcePixelBufferAttributes destinationPixelBufferAttributes nextFrameCount previousFrameCount"},
    {"VTLowLatencyFrameInterpolationParameters", "VTFrameProcessorParameters", "", "previousFrame interpolationPhase sourceFrame destinationFrame destinationFrames"},
    {"VTLowLatencySuperResolutionScalerConfiguration", "VTFrameProcessorConfiguration", "isSupported maximumDimensions minimumDimensions", "frameWidth frameHeight scaleFactor frameSupportedPixelFormats sourcePixelBufferAttributes destinationPixelBufferAttributes nextFrameCount previousFrameCount"},
    {"VTLowLatencySuperResolutionScalerParameters", "VTFrameProcessorParameters", "", "sourceFrame destinationFrame destinationFrames"},
    {"VTMotionBlurConfiguration", "VTFrameProcessorConfiguration", "supportedRevisions defaultRevision isSupported maximumDimensions minimumDimensions", "frameWidth frameHeight usePrecomputedFlow qualityPrioritization revision frameSupportedPixelFormats sourcePixelBufferAttributes destinationPixelBufferAttributes nextFrameCount previousFrameCount"},
    {"VTMotionBlurParameters", "VTFrameProcessorParameters", "", "nextFrame previousFrame nextOpticalFlow previousOpticalFlow motionBlurStrength submissionMode sourceFrame destinationFrame destinationFrames"},
    {"VTOpticalFlowConfiguration", "VTFrameProcessorConfiguration", "supportedRevisions defaultRevision isSupported maximumDimensions minimumDimensions", "frameWidth frameHeight qualityPrioritization revision frameSupportedPixelFormats sourcePixelBufferAttributes destinationPixelBufferAttributes nextFrameCount previousFrameCount"},
    {"VTOpticalFlowParameters", "VTFrameProcessorParameters", "", "nextFrame submissionMode destinationOpticalFlow sourceFrame destinationFrame destinationFrames"},
    {"VTSuperResolutionScalerConfiguration", "VTFrameProcessorConfiguration", "supportedRevisions defaultRevision supportedScaleFactors isSupported maximumDimensions minimumDimensions", "frameWidth frameHeight inputType usesPrecomputedFlow scaleFactor qualityPrioritization revision configurationModelStatus configurationModelPercentageAvailable frameSupportedPixelFormats sourcePixelBufferAttributes destinationPixelBufferAttributes nextFrameCount previousFrameCount"},
    {"VTSuperResolutionScalerParameters", "VTFrameProcessorParameters", "", "previousFrame previousOutputFrame opticalFlow submissionMode sourceFrame destinationFrame destinationFrames"},
    {"VTTemporalNoiseFilterConfiguration", "VTFrameProcessorConfiguration", "supportedSourcePixelFormats isSupported maximumDimensions minimumDimensions", "frameWidth frameHeight frameSupportedPixelFormats sourcePixelBufferAttributes destinationPixelBufferAttributes nextFrameCount previousFrameCount"},
    {"VTTemporalNoiseFilterParameters", "VTFrameProcessorParameters", "", "nextFrames previousFrames filterStrength hasDiscontinuity sourceFrame destinationFrame destinationFrames"},
};


static NSArray *VTCLASSShapes(void)
{
    static NSArray *shapes;
    if (!shapes) {
        NSMutableArray *collected = [NSMutableArray array];
        for (unsigned i = 0; i < sizeof(vtClassShapes) / sizeof(vtClassShapes[0]); i++) {
            [collected addObject:@{
                @"name": @(vtClassShapes[i].name),
                @"protocol": @(vtClassShapes[i].protocol),
                @"classProperties": @(vtClassShapes[i].classProperties),
                @"instanceProperties": @(vtClassShapes[i].instanceProperties),
            }];
        }
        shapes = collected;
    }
    return shapes;
}

static NSArray *Words(NSString *text)
{
    if (!text.length)
        return @[];
    NSMutableArray *words = [NSMutableArray array];
    for (NSString *word in [text componentsSeparatedByString:@" "])
        if (word.length)
            [words addObject:word];
    return words;
}

void vtclass_run(CertificateRecorder record)
{
    NSString *covered = [NSString stringWithContentsOfFile:@(getenv("VTCLASS_COVERED")) encoding:NSUTF8StringEncoding error:NULL] ?: @"";
    NSMutableSet *enabled = [NSMutableSet set];
    for (NSString *line in [covered componentsSeparatedByString:@"\n"]) {
        NSString *name = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (name.length)
            [enabled addObject:name];
    }

    for (NSDictionary *shape in VTCLASSShapes()) {
        NSString *declared = shape[@"name"];
        if (![enabled containsObject:declared])
            continue;
        NSString *lookup = nil;
        if ([declared isEqualToString:@"VTFrameProcessor"])                  lookup = @VTCLASS_NAME(VTFrameProcessor);
        else if ([declared isEqualToString:@"VTFrameProcessorFrame"])         lookup = @VTCLASS_NAME(VTFrameProcessorFrame);
        else if ([declared isEqualToString:@"VTFrameProcessorOpticalFlow"])   lookup = @VTCLASS_NAME(VTFrameProcessorOpticalFlow);
        else if ([declared isEqualToString:@"VTFrameRateConversionConfiguration"]) lookup = @VTCLASS_NAME(VTFrameRateConversionConfiguration);
        else if ([declared isEqualToString:@"VTFrameRateConversionParameters"])   lookup = @VTCLASS_NAME(VTFrameRateConversionParameters);
        else if ([declared isEqualToString:@"VTLowLatencyFrameInterpolationConfiguration"]) lookup = @VTCLASS_NAME(VTLowLatencyFrameInterpolationConfiguration);
        else if ([declared isEqualToString:@"VTLowLatencyFrameInterpolationParameters"])   lookup = @VTCLASS_NAME(VTLowLatencyFrameInterpolationParameters);
        else if ([declared isEqualToString:@"VTLowLatencySuperResolutionScalerConfiguration"]) lookup = @VTCLASS_NAME(VTLowLatencySuperResolutionScalerConfiguration);
        else if ([declared isEqualToString:@"VTLowLatencySuperResolutionScalerParameters"])   lookup = @VTCLASS_NAME(VTLowLatencySuperResolutionScalerParameters);
        else if ([declared isEqualToString:@"VTMotionBlurConfiguration"])   lookup = @VTCLASS_NAME(VTMotionBlurConfiguration);
        else if ([declared isEqualToString:@"VTMotionBlurParameters"])      lookup = @VTCLASS_NAME(VTMotionBlurParameters);
        else if ([declared isEqualToString:@"VTOpticalFlowConfiguration"])  lookup = @VTCLASS_NAME(VTOpticalFlowConfiguration);
        else if ([declared isEqualToString:@"VTOpticalFlowParameters"])     lookup = @VTCLASS_NAME(VTOpticalFlowParameters);
        else if ([declared isEqualToString:@"VTSuperResolutionScalerConfiguration"]) lookup = @VTCLASS_NAME(VTSuperResolutionScalerConfiguration);
        else if ([declared isEqualToString:@"VTSuperResolutionScalerParameters"])   lookup = @VTCLASS_NAME(VTSuperResolutionScalerParameters);
        else if ([declared isEqualToString:@"VTTemporalNoiseFilterConfiguration"]) lookup = @VTCLASS_NAME(VTTemporalNoiseFilterConfiguration);
        else if ([declared isEqualToString:@"VTTemporalNoiseFilterParameters"])   lookup = @VTCLASS_NAME(VTTemporalNoiseFilterParameters);
        if (!lookup) {
            record([@"class.unknown" stringByAppendingString:declared], @"1");
            continue;
        }
        Class cls = NSClassFromString(lookup);
        record([@"class." stringByAppendingString:declared], cls ? @"1" : @"0");
        if (!cls)
            continue;
        NSString *proto = shape[@"protocol"];
        if (proto.length)
            record([@"conforms." stringByAppendingString:declared], [cls conformsToProtocol:NSProtocolFromString(proto)] ? @"1" : @"0");
        for (NSString *accessor in [Words(shape[@"classProperties"]) arrayByAddingObjectsFromArray:Words(shape[@"instanceProperties"])]) {
            SEL selector = NSSelectorFromString(accessor);
            NSString *tag = [NSString stringWithFormat:@"%@.%@", declared, accessor];
            record([@"selector." stringByAppendingString:tag], NSStringFromSelector(selector));
            record([@"isClass." stringByAppendingString:tag], class_getClassMethod(cls, selector) ? @"1" : @"0");
            record([@"isInstance." stringByAppendingString:tag], [cls instancesRespondToSelector:selector] ? @"1" : @"0");
        }
    }
    vtclass_roundtrip(record);
}
