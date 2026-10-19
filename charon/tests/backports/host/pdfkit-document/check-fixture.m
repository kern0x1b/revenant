#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#include <stdio.h>
#include <string.h>

static int check(NSString *path, NSString *dir)
{
    NSData *raw = [NSData dataWithContentsOfFile:path];
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)raw);
    CGPDFDocumentRef document = provider ? CGPDFDocumentCreateWithProvider(provider) : NULL;
    if (provider)
        CGDataProviderRelease(provider);
    if (document == NULL) {
        printf("  fixture: %s does not open\n", path.lastPathComponent.UTF8String);
        return 1;
    }
    int bad = 0;
    size_t pages = (size_t)CGPDFDocumentGetNumberOfPages(document);
    NSString *name = path.lastPathComponent;
    long expectPages = 1;
    NSString *expectText = nil;
    NSString *manifestPath = [[dir stringByAppendingPathComponent:@"drew.txt"] copy];
    if (manifestPath != nil) {
        for (NSString *line in [[NSString stringWithContentsOfFile:manifestPath encoding:NSUTF8StringEncoding error:NULL]
                                 componentsSeparatedByString:@"\n"]) {
            NSArray *parts = [line componentsSeparatedByString:@"\t"];
            if (parts.count >= 2 && [parts[0] isEqualToString:name]) {
                expectPages = [parts[1] integerValue];
                if (parts.count >= 3 && [parts[2] length] && ![parts[2] isEqualToString:@"geometry-only"])
                    expectText = parts[2];
            }
        }
    }
    if (expectPages == 0) {
        printf("  fixture: %s was drawn with no pages, so its text is nothing and the run compares none\n",
               name.UTF8String);
        CGPDFDocumentRelease(document);
        return 0;
    }
    for (size_t i = 1; i <= pages; i++) {
        if (expectText == nil) {
            printf("  fixture: %s page %zu is geometry-only, read for its boxes and not asked for text\n",
                   path.lastPathComponent.UTF8String, i);
            continue;
        }
        CGPDFPageRef page = CGPDFDocumentGetPage(document, i);
        CGPDFDictionaryRef dictionary = CGPDFPageGetDictionary(page);
        CGPDFObjectRef contents = NULL;
        CGPDFDictionaryGetObject(dictionary, "Contents", &contents);
        NSMutableData *joined = [NSMutableData data];
        if (contents == NULL) {
            printf("  fixture: %s page %zu has no /Contents\n", path.lastPathComponent.UTF8String, i);
            bad++;
            continue;
        }
        if (CGPDFObjectGetType(contents) == kCGPDFObjectTypeStream) {
            CGPDFStreamRef one = NULL;
            CGPDFObjectGetValue(contents, kCGPDFObjectTypeStream, &one);
            [joined appendData:(__bridge_transfer NSData *)CGPDFStreamCopyData(one, NULL)];
        } else if (CGPDFObjectGetType(contents) == kCGPDFObjectTypeArray) {
            CGPDFArrayRef array = NULL;
            CGPDFObjectGetValue(contents, kCGPDFObjectTypeArray, &array);
            for (size_t k = 0; k < CGPDFArrayGetCount(array); k++) {
                CGPDFObjectRef one = NULL;
                CGPDFArrayGetObject(array, k + 1, &one);
                if (one && CGPDFObjectGetType(one) == kCGPDFObjectTypeStream) {
                    CGPDFStreamRef stream = NULL;
                    CGPDFObjectGetValue(one, kCGPDFObjectTypeStream, &stream);
                    [joined appendData:(__bridge_transfer NSData *)CGPDFStreamCopyData(stream, NULL)];
                }
            }
        }
        if (joined.length == 0) {
            printf("  fixture: %s page %zu has no content bytes\n", path.lastPathComponent.UTF8String, i);
            bad++;
            continue;
        }
        printf("  fixture: %s page %zu content stream: %.*s|\n", path.lastPathComponent.UTF8String, i,
               (int)MIN(joined.length, 90), (const char *)joined.bytes);
        CFDataRef data = (__bridge_retained CFDataRef)joined;
        CFIndex length = CFDataGetLength(data);
        const char *bytes = (const char *)CFDataGetBytePtr(data);
        NSString *want = [expectText isEqualToString:@"page N"] ? [NSString stringWithFormat:@"page %zu", i]
                                                                        : expectText;
        BOOL hasShow = length > 2 && memmem(bytes, (size_t)length, "Tj", 2) != NULL;
        BOOL hasText = memmem(bytes, (size_t)length, want.UTF8String, want.length) != NULL;
        if (hasShow && hasText) {
            printf("  fixture: content stream carries BT..Tj with (%s) - %s page %zu\n",
                   want.UTF8String, path.lastPathComponent.UTF8String, i);
        } else {
            printf("  fixture: %s page %zu carries %s but not the text (%s)\n",
                   path.lastPathComponent.UTF8String, i, hasShow ? "a Tj" : "no Tj",
                   hasText ? "which is there" : "which is missing");
            bad++;
        }
    }
    CGPDFDocumentRelease(document);
    return bad;
}

int main(int argc, char **argv)
{
    if (argc < 2) { fprintf(stderr, "usage: check-fixture.m <fixtures-dir>\n"); return 2; }
    NSString *dir = @(argv[1]);
    NSFileManager *files = [NSFileManager defaultManager];
    NSArray *names = [[files contentsOfDirectoryAtPath:dir error:NULL] sortedArrayUsingSelector:@selector(compare:)];
    int bad = 0;
    for (NSString *name in names) {
        if (![name hasSuffix:@".pdf"])
            continue;
        bad += check([dir stringByAppendingPathComponent:name], dir);
    }
    printf("fixture check: %s\n", bad ? "at least one fixture carries no text" : "every fixture carries its text");
    return bad ? 1 : 0;
}
