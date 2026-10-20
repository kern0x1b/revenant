#import <Foundation/Foundation.h>

BOOL revenant_property_list_write(id value, NSURL *url, NSError **error);
id revenant_property_list_read(NSURL *url, Class wanted, NSString *kind, NSError **error);

@implementation NSArray (RevenantURLContents)

- (BOOL)writeToURL:(NSURL *)url error:(NSError **)error
{
    return revenant_property_list_write(self, url, error);
}

- (instancetype)initWithContentsOfURL:(NSURL *)url error:(NSError **)error
{
    NSArray *read = revenant_property_list_read(url, [NSArray class], @"array", error);
    return read ? [self initWithArray:read] : nil;
}

+ (instancetype)arrayWithContentsOfURL:(NSURL *)url error:(NSError **)error
{
    NSArray *read = revenant_property_list_read(url, [NSArray class], @"array", error);
    return read ? [[self alloc] initWithArray:read] : nil;
}

@end
