#import <Foundation/Foundation.h>

#ifdef REVENANT_HOST_BUILD
#import "RevenantURLParser.h"
#endif

static NSString *field(NSString *value)
{
    return value ? value : @"(nil)";
}

static NSString *url_string(NSString *input, BOOL encoding)
{
#ifdef REVENANT_HOST_BUILD
    return revenant_url_nsurl(input, encoding);
#else
    return [NSURL URLWithString:input encodingInvalidCharacters:encoding].absoluteString;
#endif
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
                         field(components.percentEncodedQuery), field(components.percentEncodedFragment), field(components.string),
                         field(components.encodedHost)]
                       componentsJoinedByString:@"\t"];
            }
            NSURLComponents *encoded = [NSURLComponents componentsWithString:input encodingInvalidCharacters:YES];
            NSString *encodedRow = encoded ? [@[field(encoded.string), field(encoded.encodedHost), field(encoded.percentEncodedPath)] componentsJoinedByString:@"\t"] : @"nil";
            NSURLComponents *strict = [NSURLComponents componentsWithString:input encodingInvalidCharacters:NO];
            row = [row stringByAppendingFormat:@"\tencoding:%@\tstrict:%@", encodedRow, strict ? field(strict.string) : @"nil"];
            NSString *lenientURL = url_string(input, YES);
            NSString *strictURL = url_string(input, NO);
            row = [row stringByAppendingFormat:@"\turl:%@\turlstrict:%@", lenientURL ? field(lenientURL) : @"nil", strictURL ? field(strictURL) : @"nil"];
            printf("%lu\t%s\n", (unsigned long)index, row.UTF8String);
            index++;
        }
    }
    return 0;
}
