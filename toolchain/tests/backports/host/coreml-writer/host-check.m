#import <Foundation/Foundation.h>
#import <CoreML/CoreML.h>

static NSString *describe(MLModelDescription *description)
{
    NSMutableString *text = [NSMutableString string];
    for (NSString *name in [description.inputDescriptionsByName.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        [text appendFormat:@"input %@ %@\n", name, description.inputDescriptionsByName[name]];
    }
    for (NSString *name in [description.outputDescriptionsByName.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        [text appendFormat:@"output %@ %@\n", name, description.outputDescriptionsByName[name]];
    }
    return text;
}

static MLModel *load(const char *path, const char *label)
{
    NSError *error = nil;
    NSURL *source = [NSURL fileURLWithPath:[NSString stringWithUTF8String:path]];
    NSURL *compiled = [MLModel compileModelAtURL:source error:&error];
    if (compiled == nil) {
        printf("%s: the host cannot compile it: %s\n", label, error.localizedDescription.UTF8String);
        return nil;
    }
    MLModel *model = [MLModel modelWithContentsOfURL:compiled error:&error];
    if (model == nil) {
        printf("%s: the host cannot load it: %s\n", label, error.localizedDescription.UTF8String);
    }
    return model;
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc != 3) {
            printf("usage: host-check <original.mlmodel> <written.mlmodel>\n");
            return 2;
        }
        MLModel *original = load(argv[1], "original");
        MLModel *written = load(argv[2], "written");
        if (original == nil || written == nil) {
            return 1;
        }
        printf("host reads the written model: yes\n");
        BOOL same = [describe(original.modelDescription) isEqualToString:describe(written.modelDescription)];
        printf("descriptions equal: %s\n", same ? "yes" : "no");
        return same ? 0 : 1;
    }
}
