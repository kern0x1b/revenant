#import "VNTextRecognizer.h"
#import <CoreGraphics/CoreGraphics.h>
#import <ImageIO/ImageIO.h>
#import <Vision/Vision.h>
#include <algorithm>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <vector>

static const CGFloat TOLERANCE = 0.04;
static const CGFloat FAST_TEXT_ERROR = 0.2;
static const NSInteger RECORDED_MACOS_MAJOR = 27;

static bool negative_control;

static void require(bool holds, NSString *message)
{
    if (holds)
        return;
    std::fprintf(stderr, "%s\n", message.UTF8String);
    std::exit(1);
}

static void expect(bool holds, NSString *message)
{
    if (holds != negative_control)
        return;
    std::fprintf(stderr, "%s%s\n", negative_control ? "negative control: " : "", message.UTF8String);
    std::exit(1);
}

static NSUInteger edit_distance(NSString *a, NSString *b)
{
    NSUInteger count = b.length;
    std::vector<NSUInteger> previous(count + 1), current(count + 1);
    for (NSUInteger column = 0; column <= count; ++column)
        previous[column] = column;
    for (NSUInteger row = 1; row <= a.length; ++row) {
        current[0] = row;
        for (NSUInteger column = 1; column <= count; ++column) {
            NSUInteger substitution = previous[column - 1] + ([a characterAtIndex:row - 1] == [b characterAtIndex:column - 1] ? 0 : 1);
            current[column] = std::min(std::min(previous[column] + 1, current[column - 1] + 1), substitution);
        }
        previous.swap(current);
    }
    return previous[count];
}

static CGFloat deviation(CGRect a, CGRect b)
{
    return std::max(std::max(std::fabs(a.origin.x - b.origin.x), std::fabs(a.origin.y - b.origin.y)),
                    std::max(std::fabs(a.size.width - b.size.width), std::fabs(a.size.height - b.size.height)));
}

static NSArray *expected_fixtures(NSString *path)
{
    NSString *text = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
    require(text.length > 0, [NSString stringWithFormat:@"no expectations in %@", path]);
    NSMutableArray *fixtures = [NSMutableArray array];
    NSMutableDictionary *fixture = nil;
    for (NSString *row in [text componentsSeparatedByString:@"\n"]) {
        NSArray *fields = [row componentsSeparatedByString:@" "];
        if ([fields[0] isEqualToString:@"fixture"] && fields.count == 4) {
            fixture = [@{@"name": fields[1], @"languages": fields[3], @"lines": [NSMutableArray array]} mutableCopy];
            [fixtures addObject:fixture];
        } else if ([fields[0] isEqualToString:@"line"] && fields.count >= 7 && fixture != nil) {
            CGRect bounds = CGRectMake([fields[2] doubleValue], [fields[3] doubleValue], [fields[4] doubleValue], [fields[5] doubleValue]);
            NSString *string = [[fields subarrayWithRange:NSMakeRange(6, fields.count - 6)] componentsJoinedByString:@" "];
            [fixture[@"lines"] addObject:@{@"text": string, @"bounds": RevenantVisionRectValue(bounds)}];
        }
    }
    return fixtures;
}

static CGImageRef image_at(NSString *path)
{
    CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:path], NULL);
    CGImageRef image = source != NULL ? CGImageSourceCreateImageAtIndex(source, 0, NULL) : NULL;
    if (source != NULL)
        CFRelease(source);
    return image;
}

static NSDictionary *options(NSString *root, NSArray *languages, BOOL fast, CGRect region)
{
    return @{@"tessdata": root, @"fast": @(fast), @"revision": @3, @"languages": languages, @"correction": @YES,
             @"customWords": @[], @"minimumTextHeight": @0, @"regionOfInterest": RevenantVisionRectValue(region)};
}

static NSArray *recognize(CGImageRef image, NSDictionary *options, NSError **error)
{
    return RevenantVisionTextLines((__bridge id)image, kCGImagePropertyOrientationUp, options, error);
}

static void expect_lines(NSArray *lines, NSArray *expected, NSString *name, BOOL fast)
{
    expect(lines.count == expected.count, [NSString stringWithFormat:@"%@ has %lu lines, expected %lu", name,
                                                                     (unsigned long)lines.count, (unsigned long)expected.count]);
    CGFloat worst = 0;
    for (NSUInteger index = 0; index < std::min(lines.count, expected.count); ++index) {
        NSDictionary *line = lines[index];
        NSDictionary *want = expected[index];
        NSUInteger errors = edit_distance(line[@"string"], want[@"text"]);
        expect(errors <= (fast ? FAST_TEXT_ERROR * [want[@"text"] length] : 0),
               [NSString stringWithFormat:@"%@ line %lu reads \"%@\", expected \"%@\"", name, (unsigned long)index, line[@"string"], want[@"text"]]);
        CGFloat measured = deviation(RevenantVisionRectFromValue(line[@"bounds"]), RevenantVisionRectFromValue(want[@"bounds"]));
        worst = std::max(worst, measured);
        expect(measured <= TOLERANCE, [NSString stringWithFormat:@"%@ line %lu box deviates by %.4f from Vision", name, (unsigned long)index, measured]);
    }
    std::printf("%s: %lu lines, worst box deviation %.4f\n", name.UTF8String, (unsigned long)lines.count, worst);
}

static void expect_words(NSArray *lines, NSString *name)
{
    for (NSDictionary *line in lines) {
        NSString *string = line[@"string"];
        NSUInteger previous = 0;
        for (NSDictionary *word in line[@"words"]) {
            NSRange range = [word[@"range"] rangeValue];
            expect(range.length > 0 && range.location >= previous && NSMaxRange(range) <= string.length,
                   [NSString stringWithFormat:@"%@ word range {%lu, %lu} in \"%@\" is out of order", name,
                                              (unsigned long)range.location, (unsigned long)range.length, string]);
            previous = NSMaxRange(range);
        }
    }
}

static void expect_fixtures(NSString *data, NSString *root, BOOL fast)
{
    for (NSDictionary *fixture in expected_fixtures([data stringByAppendingPathComponent:@"expected.txt"])) {
        NSString *language = fixture[@"languages"];
        NSString *name = [fixture[@"name"] stringByAppendingString:fast ? @" (fast)" : @""];
        if (fast && ![@[@"en-US", @"fr-FR", @"it-IT", @"de-DE", @"es-ES", @"pt-BR"] containsObject:language])
            continue;
        CGImageRef image = image_at([data stringByAppendingPathComponent:fixture[@"name"]]);
        require(image != NULL, [NSString stringWithFormat:@"%@ cannot be read", fixture[@"name"]]);
        NSError *error = nil;
        NSArray *lines = recognize(image, options(root, @[language], fast, CGRectMake(0, 0, 1, 1)), &error);
        CGImageRelease(image);
        require(lines != nil && error == nil, [NSString stringWithFormat:@"%@ failed: %@", name, error.localizedDescription]);
        expect_lines(lines, fixture[@"lines"], name, fast);
        expect_words(lines, name);
    }
}

static NSDictionary *recorded_languages(NSString *data)
{
    NSString *text = [NSString stringWithContentsOfFile:[data stringByAppendingPathComponent:@"languages.txt"] encoding:NSUTF8StringEncoding error:NULL];
    require(text.length > 0, [NSString stringWithFormat:@"no recorded languages in %@", data]);
    NSMutableDictionary *recorded = [NSMutableDictionary dictionary];
    NSString *key = nil;
    for (NSString *row in [text componentsSeparatedByString:@"\n"]) {
        NSArray *fields = [row componentsSeparatedByString:@" "];
        if ([fields[0] isEqualToString:@"case"] && fields.count == 3) {
            key = [NSString stringWithFormat:@"%@ %@", fields[1], fields[2]];
        } else if ([fields[0] isEqualToString:@"languages"] && key != nil) {
            recorded[key] = [fields subarrayWithRange:NSMakeRange(1, fields.count - 1)];
        }
    }
    return recorded;
}

static NSArray *vision_languages(NSUInteger revision, BOOL fast)
{
    NSError *error = nil;
    NSArray *languages = [VNRecognizeTextRequest supportedRecognitionLanguagesForTextRecognitionLevel:fast ? VNRequestTextRecognitionLevelFast : VNRequestTextRecognitionLevelAccurate
                                                                                                revision:revision error:&error];
    require(languages != nil && error == nil, [NSString stringWithFormat:@"Vision does not list revision %lu languages", (unsigned long)revision]);
    return languages;
}

static void expect_languages(NSString *data, NSString *root)
{
    NSDictionary *recorded = recorded_languages(data);
    BOOL reference_host = [VNRecognizeTextRequest respondsToSelector:@selector(supportedRecognitionLanguagesForTextRecognitionLevel:revision:error:)]
                          && [NSProcessInfo processInfo].operatingSystemVersion.majorVersion == RECORDED_MACOS_MAJOR;
    NSArray *cases = @[@[@3, @NO], @[@2, @NO], @[@1, @NO], @[@3, @YES]];
    for (NSArray *item in cases) {
        NSUInteger revision = [item[0] unsignedIntegerValue];
        BOOL fast = [item[1] boolValue];
        NSString *key = [NSString stringWithFormat:@"%lu %@", (unsigned long)revision, fast ? @"fast" : @"accurate"];
        NSArray *want = recorded[key];
        require(want != nil, [NSString stringWithFormat:@"no recorded languages for revision %@", key]);
        NSArray *backport = RevenantVisionTextLanguages(root, revision, fast);
        expect(backport.count == want.count && [[NSSet setWithArray:backport] isEqualToSet:[NSSet setWithArray:want]],
               [NSString stringWithFormat:@"revision %@ languages are %@, recorded %@", key, backport, want]);
        if (reference_host) {
            NSArray *apple = vision_languages(revision, fast);
            expect(apple.count == want.count && [[NSSet setWithArray:apple] isEqualToSet:[NSSet setWithArray:want]],
                   [NSString stringWithFormat:@"revision %@ languages are %@ on this host, recorded %@", key, apple, want]);
        }
    }
    expect(RevenantVisionTextLanguages(@"/nonexistent", 3, NO).count == 0, @"languages are listed without models");
}

static void expect_region(NSString *data, NSString *root)
{
    CGImageRef image = image_at([data stringByAppendingPathComponent:@"en-two-lines.png"]);
    require(image != NULL, @"en-two-lines.png cannot be read");
    NSError *error = nil;
    NSArray *lines = recognize(image, options(root, @[@"en-US"], NO, CGRectMake(0, 0.6, 1, 0.4)), &error);
    CGImageRelease(image);
    require(lines != nil && error == nil, [NSString stringWithFormat:@"region of interest failed: %@", error.localizedDescription]);
    expect(lines.count == 1 && [lines[0][@"string"] isEqualToString:@"Hello, world"],
           [NSString stringWithFormat:@"region of interest reads %lu lines", (unsigned long)lines.count]);
    if (lines.count == 1)
        expect(deviation(RevenantVisionRectFromValue(lines[0][@"bounds"]), CGRectMake(0.069782, 0.730859, 0.312157, 0.123142)) <= TOLERANCE,
               @"region of interest box is not in image coordinates");
}

static void expect_failures(NSString *data, NSString *root)
{
    CGImageRef image = image_at([data stringByAppendingPathComponent:@"en-two-lines.png"]);
    require(image != NULL, @"en-two-lines.png cannot be read");
    CGRect full = CGRectMake(0, 0, 1, 1);
    NSError *error = nil;
    NSArray *lines = recognize(image, options(@"/nonexistent", @[@"en-US"], NO, full), &error);
    expect(lines == nil && error != nil, @"a missing model is not an error");
    error = nil;
    lines = recognize(image, options(root, @[@"ru-RU"], YES, full), &error);
    expect(lines == nil && error != nil, @"Russian is accepted at the fast level");
    error = nil;
    lines = recognize(image, options(root, @[@"xx-XX"], NO, full), &error);
    expect(lines == nil && error != nil, @"an unknown language is accepted");
    CGImageRelease(image);
}

int main(int argc, char **argv)
{
    int first = argc > 1 && std::strcmp(argv[1], "--negative") == 0 ? 2 : 1;
    negative_control = first == 2;
    require(argc >= first + 2, @"usage: text_test [--negative] FIXTURES TESSDATA");
    NSString *data = [NSString stringWithUTF8String:argv[first]];
    NSString *root = [NSString stringWithUTF8String:argv[first + 1]];
    expect_fixtures(data, root, NO);
    expect_fixtures(data, root, YES);
    expect_languages(data, root);
    expect_region(data, root);
    expect_failures(data, root);
    return 0;
}
