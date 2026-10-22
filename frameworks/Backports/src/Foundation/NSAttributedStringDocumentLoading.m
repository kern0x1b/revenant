#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static const void *DocumentAttributesKey = &DocumentAttributesKey;

@implementation NSAttributedString (RevenantDocumentLoading)

- (instancetype)initWithData:(NSData *)data options:(NSDictionary<NSString *, id> *)options documentAttributes:(NSDictionary<NSString *, id> * _Nullable *)docAttributes error:(NSError * _Nullable *)error
{
    if (docAttributes)
        *docAttributes = nil;
    if (error)
        *error = nil;
    return [self initWithString:@"" attributes:nil];
}

- (instancetype)initWithData:(NSData *)data ofType:(NSString *)type error:(NSError * _Nullable *)error
{
    if (error)
        *error = nil;
    return [self initWithString:@"" attributes:nil];
}

- (NSDictionary<NSString *, id> *)documentAttributes
{
    return objc_getAssociatedObject(self, DocumentAttributesKey);
}

@end