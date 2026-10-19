#import <Foundation/Foundation.h>

#import <CoreGraphics/CoreGraphics.h>

typedef void (^VisionRecorder)(NSString *name, NSString *value);

typedef struct {
    NSURL *glm_classifier;
    NSURL *image;
    NSURL *vision;
} CoreMLModels;

CoreMLModels vision_coreml_models(void);
CGImageRef vision_picture(size_t wide, size_t high);

void vision_run(VisionRecorder record, CoreMLModels models);
