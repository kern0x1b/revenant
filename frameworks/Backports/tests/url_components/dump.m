#import <Foundation/Foundation.h>

static NSString *field(NSString *value)
{
    return value ? value : @"(nil)";
}

int main(int argc, const char **argv)
{
    @autoreleasepool {
        if (argc != 2) return 2;
        NSError *error = nil;
        NSString *text = [NSString stringWithContentsOfFile:[NSString stringWithUTF8String:argv[1]] encoding:NSUTF8StringEncoding error:&error];
        if (!text) return 2;
        NSUInteger index = 0;
        for (NSString *line in [text componentsSeparatedByString:@"\n"]) {
            if (line.length == 0) continue;
            NSString *input = [line isEqualToString:@"<empty>"] ? @"" : line;
            NSURLComponents *components = [NSURLComponents componentsWithString:input];
            NSString *row;
            if (!components) {
                row = @"nil";
            } else {
                row = [@[field(components.scheme), field(components.percentEncodedUser), field(components.percentEncodedPassword),
                         field(components.percentEncodedHost), field(components.port.stringValue), field(components.percentEncodedPath),
                         field(components.percentEncodedQuery), field(components.percentEncodedFragment), field(components.string)]
                       componentsJoinedByString:@"\t"];
            }
            printf("%lu\t%s\n", (unsigned long)index, row.UTF8String);
            index++;
        }
    }
    return 0;
}
