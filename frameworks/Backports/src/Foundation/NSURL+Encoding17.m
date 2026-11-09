#import <Foundation/Foundation.h>
#import "RevenantURLParser.h"

@implementation NSURL (RevenantEncoding)

+ (NSURL *)URLWithString:(NSString *)string encodingInvalidCharacters:(BOOL)encoding
{
    return [[self alloc] initWithString:string encodingInvalidCharacters:encoding];
}

- (instancetype)initWithString:(NSString *)string encodingInvalidCharacters:(BOOL)encoding
{
    NSString *written = revenant_url_standard(string, encoding, YES);
    return written ? [self initWithString:written] : nil;
}

@end
