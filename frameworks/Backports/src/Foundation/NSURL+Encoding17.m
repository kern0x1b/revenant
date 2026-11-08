#import <Foundation/Foundation.h>

@implementation NSURL (RevenantEncoding)

+ (NSURL *)URLWithString:(NSString *)string encodingInvalidCharacters:(BOOL)encoding
{
    return [[self alloc] initWithString:string encodingInvalidCharacters:encoding];
}

- (instancetype)initWithString:(NSString *)string encodingInvalidCharacters:(BOOL)encoding
{
    NSString *written = [[NSURLComponents alloc] initWithString:string encodingInvalidCharacters:encoding].string;
    return written ? [self initWithString:written] : nil;
}

@end
