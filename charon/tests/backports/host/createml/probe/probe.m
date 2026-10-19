// The synchronous Objective-C route, which the Swift overlay's unavailability does not gate:
//   +[MLModel compileModelAtURL:error:]   +[MLModel modelWithContentsOfURL:error:]
//   MLDictionaryFeatureProvider with an MLMultiArray input
//   -[MLModel predictionFromFeatures:error:]
#import <Foundation/Foundation.h>
#import <CoreML/CoreML.h>

static int fail(const char *what, NSError *error) {
  fprintf(stderr, "%s FAILED: %s\n", what,
          error == nil ? "no error object" : [[error localizedDescription] UTF8String]);
  return 1;
}

int main(int argc, const char **argv) {
  @autoreleasepool {
    const char *path = argc > 1 ? argv[1] : "/tmp/w/port.mlmodel";
    NSURL *url = [NSURL fileURLWithPath:@(path)];

    // 1. Compile: the framework's own compiler, synchronous. This is what says a file is a MODEL
    //    rather than a file with the right extension, and it is a validator as well as a compiler.
    NSError *compileError = nil;
    NSURL *compiled = [MLModel compileModelAtURL:url error:&compileError];
    if (compiled == nil) { return fail("COMPILE", compileError); }
    fprintf(stderr, "compiled to %s\n", [[compiled path] UTF8String]);

    // 2. Load the compiled model.
    NSError *loadError = nil;
    MLModel *model = [MLModel modelWithContentsOfURL:compiled error:&loadError];
    if (model == nil) { return fail("LOAD", loadError); }

    MLModelDescription *description = model.modelDescription;
    fprintf(stderr, "loaded; inputs %s | outputs %s\n",
            [description.inputDescriptionsByName.allKeys componentsJoinedByString:@","].UTF8String,
            [description.outputDescriptionsByName.allKeys componentsJoinedByString:@","].UTF8String);

    // 3. Predict, synchronously, through the Objective-C method. Two API details stop an Objective-C
    //    probe first and both are here: MLMultiArray's subscripts take a FLAT index, not an array of
    //    them, and the dictionary provider's initialiser has an `error:` out-parameter.
    double rows[][2] = {{2.0, 4.0}, {1.0, 1.0}, {0.0, 0.0}, {3.0, -1.0}, {-2.5, 7.0}};
    int count = 5;
    double worst = 0.0;
    for (int i = 0; i < count; i++) {
      NSError *arrayError = nil;
      MLMultiArray *input = [[MLMultiArray alloc] initWithShape:@[@1, @2]
                                                      dataType:MLMultiArrayDataTypeDouble
                                                         error:&arrayError];
      if (input == nil) { return fail("MULTIARRAY", arrayError); }
      [input setObject:@(rows[i][0]) atIndexedSubscript:0];
      [input setObject:@(rows[i][1]) atIndexedSubscript:1];

      NSError *providerError = nil;
      MLDictionaryFeatureProvider *provider =
          [[MLDictionaryFeatureProvider alloc] initWithDictionary:@{@"x": input} error:&providerError];
      if (provider == nil) { return fail("PROVIDER", providerError); }

      NSError *predictError = nil;
      id<MLFeatureProvider> output = [model predictionFromFeatures:provider error:&predictError];
      if (output == nil) { return fail("PREDICT", predictError); }

      MLMultiArray *predicted = [output featureValueForName:@"prediction"].multiArrayValue;
      double got = [predicted objectAtIndexedSubscript:0].doubleValue;
      // The probe computes the model's OWN arithmetic: y = 3 + 2*x1 - 1.5*x2.
      double want = 3.0 + 2.0 * rows[i][0] - 1.5 * rows[i][1];
      double difference = got - want;
      if (difference < 0) difference = -difference;
      if (difference > worst) worst = difference;
      fprintf(stderr, "row (%.1f, %.1f) -> %.9f  the model's own arithmetic says %.9f\n",
              rows[i][0], rows[i][1], got, want);
    }
    fprintf(stderr, "worst difference: %.3e\n", worst);
    return worst < 1e-6 ? 0 : 2;
  }
}
