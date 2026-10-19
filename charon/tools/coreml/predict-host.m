#import <CoreML/CoreML.h>
#import <Foundation/Foundation.h>
#include <string.h>

static int failed(NSString *message) {
    fprintf(stderr, "predict-host: %s\n", message.UTF8String);
    return 1;
}

static NSArray<NSString *> *words_of(NSString *line) {
    NSMutableArray<NSString *> *words = [NSMutableArray array];
    for (NSString *word in [line componentsSeparatedByString:@" "]) {
        if (word.length > 0) {
            [words addObject:word];
        }
    }
    return words;
}

static NSString *text_of(double value) {
    return [NSString stringWithFormat:@"%.17g", value];
}

static NSArray<NSNumber *> *coordinates_of(NSInteger position, NSArray<NSNumber *> *shape) {
    NSMutableArray<NSNumber *> *coordinates = [NSMutableArray arrayWithCapacity:shape.count];
    for (NSInteger axis = (NSInteger)shape.count - 1; axis >= 0; axis--) {
        NSInteger extent = shape[(NSUInteger)axis].integerValue;
        [coordinates insertObject:@(position % extent) atIndex:0];
        position /= extent;
    }
    return coordinates;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 3) {
            return failed(@"usage: predict-host <model.mlmodel> <inputs>");
        }
        NSError *error = nil;
        NSURL *source = [NSURL fileURLWithPath:[NSString stringWithUTF8String:argv[1]]];
        NSURL *compiled = [MLModel compileModelAtURL:source error:&error];
        if (compiled == nil) {
            return failed([NSString stringWithFormat:@"compile %s: %@", argv[1], error]);
        }
        MLModel *model = [MLModel modelWithContentsOfURL:compiled error:&error];
        if (model == nil) {
            return failed([NSString stringWithFormat:@"load %s: %@", argv[1], error]);
        }

        if (strcmp(argv[2], "-") == 0) {
            printf("compiled and loaded\n");
            return 0;
        }
        NSString *inputs = [NSString stringWithContentsOfFile:[NSString stringWithUTF8String:argv[2]]
                                                     encoding:NSUTF8StringEncoding error:&error];
        if (inputs == nil) {
            return failed([NSString stringWithFormat:@"read %s: %@", argv[2], error]);
        }
        NSMutableDictionary<NSString *, MLFeatureValue *> *features = [NSMutableDictionary dictionary];
        for (NSString *line in [inputs componentsSeparatedByString:@"\n"]) {
            NSArray<NSString *> *words = words_of(line);
            if (words.count == 0) {
                continue;
            }
            if (words.count < 3 || ![words[0] isEqualToString:@"input"]) {
                return failed([NSString stringWithFormat:@"not an input line: %@", line]);
            }
            NSString *name = words[1];
            MLFeatureDescription *description = model.modelDescription.inputDescriptionsByName[name];
            if (description == nil || description.type != MLFeatureTypeMultiArray) {
                return failed([NSString stringWithFormat:@"the model has no multiArray input named %@", name]);
            }
            NSMutableArray<NSNumber *> *shape = [NSMutableArray array];
            for (NSString *extent in [words[2] componentsSeparatedByString:@"x"]) {
                [shape addObject:@(extent.integerValue)];
            }
            MLMultiArray *array = [[MLMultiArray alloc] initWithShape:shape
                                                             dataType:description.multiArrayConstraint.dataType
                                                                error:&error];
            if (array == nil) {
                return failed([NSString stringWithFormat:@"input %@: %@", name, error]);
            }
            if (array.count != (NSInteger)(words.count - 3)) {
                return failed([NSString stringWithFormat:@"input %@ has %lu values for %ld elements", name,
                               (unsigned long)(words.count - 3), (long)array.count]);
            }
            for (NSInteger at = 0; at < array.count; at++) {
                array[coordinates_of(at, shape)] = @([words[(NSUInteger)(at + 3)] doubleValue]);
            }
            features[name] = [MLFeatureValue featureValueWithMultiArray:array];
        }

        MLDictionaryFeatureProvider *provider =
            [[MLDictionaryFeatureProvider alloc] initWithDictionary:features error:&error];
        if (provider == nil) {
            return failed([NSString stringWithFormat:@"inputs: %@", error]);
        }
        id<MLFeatureProvider> answer = [model predictionFromFeatures:provider error:&error];
        if (answer == nil) {
            return failed([NSString stringWithFormat:@"predict %s: %@", argv[1], error]);
        }
        NSArray<NSString *> *names = [[answer.featureNames allObjects]
            sortedArrayUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
                return [a compare:b options:NSLiteralSearch];
            }];
        for (NSString *name in names) {
            MLFeatureValue *value = [answer featureValueForName:name];
            switch (value.type) {
                case MLFeatureTypeMultiArray: {
                    NSMutableArray<NSString *> *extents = [NSMutableArray array];
                    for (NSNumber *extent in value.multiArrayValue.shape) {
                        [extents addObject:extent.stringValue];
                    }
                    NSMutableString *line = [NSMutableString stringWithFormat:@"output %@ array %@", name,
                                             [extents componentsJoinedByString:@"x"]];
                    for (NSInteger at = 0; at < value.multiArrayValue.count; at++) {
                        NSArray<NSNumber *> *where = coordinates_of(at, value.multiArrayValue.shape);
                        [line appendFormat:@" %@", text_of([value.multiArrayValue[where] doubleValue])];
                    }
                    printf("%s\n", line.UTF8String);
                    break;
                }
                case MLFeatureTypeDouble:
                    printf("output %s double %s\n", name.UTF8String, text_of(value.doubleValue).UTF8String);
                    break;
                case MLFeatureTypeInt64:
                    printf("output %s int64 %lld\n", name.UTF8String, (long long)value.int64Value);
                    break;
                case MLFeatureTypeString:
                    printf("output %s string %s\n", name.UTF8String, value.stringValue.UTF8String);
                    break;
                case MLFeatureTypeDictionary: {
                    NSMutableString *line = [NSMutableString stringWithFormat:@"output %@ dictionary", name];
                    NSDictionary *entries = value.dictionaryValue;
                    for (NSString *key in [[entries allKeys] sortedArrayUsingSelector:@selector(compare:)]) {
                        [line appendFormat:@" %@ %@", key, text_of([entries[key] doubleValue])];
                    }
                    printf("%s\n", line.UTF8String);
                    break;
                }
                default:
                    return failed([NSString stringWithFormat:@"output %@ is a feature kind this probe does not print",
                                   name]);
            }
        }
    }
    return 0;
}
