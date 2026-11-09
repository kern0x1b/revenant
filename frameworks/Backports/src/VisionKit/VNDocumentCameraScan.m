#import "RevenantVisionKit.h"

@implementation VNDocumentCameraScan {
    NSArray<NSData *> *_pages;
    NSString *_title;
}

- (instancetype)initWithRevenantPages:(NSArray<NSData *> *)pages title:(NSString *)title
{
    if ((self = [super init])) {
        _pages = [pages copy];
        _title = [title copy];
    }
    return self;
}

- (NSUInteger)pageCount
{
    return _pages.count;
}

- (UIImage *)imageOfPageAtIndex:(NSUInteger)index
{
    if (index >= _pages.count)
        return nil;
    return [UIImage imageWithData:_pages[index]];
}

- (NSString *)title
{
    return _title;
}

@end
