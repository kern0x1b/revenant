#import <Foundation/Foundation.h>
#import "RevenantURLParser.h"

@implementation NSURLComponents (RevenantEncoding)

+ (NSURLComponents *)componentsWithString:(NSString *)string encodingInvalidCharacters:(BOOL)encoding
{
    return [[self alloc] initWithString:string encodingInvalidCharacters:encoding];
}

- (instancetype)initWithString:(NSString *)string encodingInvalidCharacters:(BOOL)encoding
{
    NSString *written = revenant_url_standard(string, encoding, NO);
    return written ? [self initWithString:written] : nil;
}

@end
