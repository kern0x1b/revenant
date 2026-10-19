#import <Foundation/Foundation.h>

BOOL charon_property_list_write(id value, NSURL *url, NSError **error);
id charon_property_list_read(NSURL *url, Class wanted, NSString *kind, NSError **error);

@implementation NSArray (CharonURLContents)

- (BOOL)writeToURL:(NSURL *)url error:(NSError **)error
{
    return charon_property_list_write(self, url, error);
}

- (instancetype)initWithContentsOfURL:(NSURL *)url error:(NSError **)error
{
    NSArray *read = charon_property_list_read(url, [NSArray class], @"array", error);
    return read ? [self initWithArray:read] : nil;
}

+ (instancetype)arrayWithContentsOfURL:(NSURL *)url error:(NSError **)error
{
    NSArray *read = charon_property_list_read(url, [NSArray class], @"array", error);
    return read ? [[self alloc] initWithArray:read] : nil;
}

@end
