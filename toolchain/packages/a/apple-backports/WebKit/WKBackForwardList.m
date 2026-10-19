#import "CharonWebKit.h"

@implementation WKBackForwardListItem {
    NSURL *_URL;
    NSString *_title;
}

+ (instancetype)charon_itemWithURL:(NSURL *)url title:(NSString *)title
{
    WKBackForwardListItem *item = [self alloc];
    item->_URL = [url copy];
    item->_title = [title copy];
    return item;
}

- (NSURL *)URL
{
    return _URL;
}

- (NSURL *)initialURL
{
    return _URL;
}

- (NSString *)title
{
    return _title;
}

- (NSString *)charon_title
{
    return _title;
}

- (void)setCharon_title:(NSString *)title
{
    _title = [title copy];
}

@end

@implementation WKBackForwardList {
    NSArray<WKBackForwardListItem *> *_items;
    NSInteger _index;
}

- (void)charon_setItems:(NSArray<WKBackForwardListItem *> *)items index:(NSInteger)index
{
    _items = [items copy];
    _index = index;
}

- (WKBackForwardListItem *)currentItem
{
    return _index >= 0 && _index < (NSInteger)_items.count ? _items[_index] : nil;
}

- (WKBackForwardListItem *)backItem
{
    return _index >= 1 && _index - 1 < (NSInteger)_items.count ? _items[_index - 1] : nil;
}

- (WKBackForwardListItem *)forwardItem
{
    return _index >= 0 && _index + 1 < (NSInteger)_items.count ? _items[_index + 1] : nil;
}

- (WKBackForwardListItem *)itemAtIndex:(NSInteger)index
{
    NSInteger position = _index + index;
    return _items.count && position >= 0 && position < (NSInteger)_items.count ? _items[position] : nil;
}

- (NSArray<WKBackForwardListItem *> *)backList
{
    return _index > 0 ? [_items subarrayWithRange:NSMakeRange(0, MIN((NSUInteger)_index, _items.count))] : @[];
}

- (NSArray<WKBackForwardListItem *> *)forwardList
{
    return _index >= 0 && _index + 1 < (NSInteger)_items.count ? [_items subarrayWithRange:NSMakeRange(_index + 1, _items.count - _index - 1)] : @[];
}

@end
