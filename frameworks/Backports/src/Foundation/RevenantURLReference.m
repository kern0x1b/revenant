#import <Foundation/Foundation.h>
#import "RevenantURLParser.h"

NSURL *revenant_url_object(NSString *written, NSURL *base)
{
    NSData *bytes = [written dataUsingEncoding:NSUTF8StringEncoding];
    if (!bytes)
        return nil;
    if (bytes.length == 0)
        return base ? [NSURL URLWithString:written relativeToURL:base] : [NSURL URLWithString:written];
    CFURLRef url = CFURLCreateWithBytes(NULL, bytes.bytes, (CFIndex)bytes.length, kCFStringEncodingUTF8, (__bridge CFURLRef)base);
    return CFBridgingRelease(url);
}

static BOOL revenant_url_scheme_character(unichar character, BOOL first)
{
    if ((character >= 'a' && character <= 'z') || (character >= 'A' && character <= 'Z'))
        return YES;
    return !first && ((character >= '0' && character <= '9') || character == '+' || character == '-' || character == '.');
}

static BOOL revenant_url_reads_as_relative(NSString *written)
{
    NSUInteger length = written.length;
    for (NSUInteger index = 0; index < length; index++) {
        unichar character = [written characterAtIndex:index];
        if (character == '/' || character == '?' || character == '#')
            return YES;
        if (character == ':') {
            if (index == 0)
                return NO;
            for (NSUInteger scheme = 0; scheme < index; scheme++) {
                if (!revenant_url_scheme_character([written characterAtIndex:scheme], scheme == 0))
                    return YES;
            }
            return NO;
        }
    }
    return YES;
}

static BOOL revenant_url_colon_in_first_segment(NSString *written)
{
    NSUInteger length = written.length;
    for (NSUInteger index = 0; index < length; index++) {
        unichar character = [written characterAtIndex:index];
        if (character == '/' || character == '?' || character == '#')
            return NO;
        if (character == ':')
            return YES;
    }
    return NO;
}

NSURL *revenant_url_reference(NSString *string, NSURL *base)
{
    NSString *written = revenant_url_nsurl(string, YES);
    if (!written)
        return nil;
    if (!base || !revenant_url_reads_as_relative(written))
        return revenant_url_object(written, nil);
    if (revenant_url_colon_in_first_segment(written))
        written = [@"./" stringByAppendingString:written];
    return revenant_url_object(written, base);
}
