#import <Foundation/Foundation.h>

BOOL charon_property_list_write(id value, NSURL *url, NSError **error);
id charon_property_list_read(NSURL *url, Class wanted, NSString *kind, NSError **error);

@implementation NSDictionary (CharonURLContents)

- (BOOL)writeToURL:(NSURL *)url error:(NSError **)error
{
    return charon_property_list_write(self, url, error);
}

- (instancetype)initWithContentsOfURL:(NSURL *)url error:(NSError **)error
{
    NSDictionary *read = charon_property_list_read(url, [NSDictionary class], @"dictionary", error);
    return read ? [self initWithDictionary:read] : nil;
}

+ (instancetype)dictionaryWithContentsOfURL:(NSURL *)url error:(NSError **)error
{
    NSDictionary *read = charon_property_list_read(url, [NSDictionary class], @"dictionary", error);
    return read ? [[self alloc] initWithDictionary:read] : nil;
}

@end
