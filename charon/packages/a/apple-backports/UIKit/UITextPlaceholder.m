#import <UIKit/UIKit.h>

@implementation UITextPlaceholder {
@private
    NSArray<UITextSelectionRect *> *_rects;
}

- (NSArray<UITextSelectionRect *> *)rects
{
    return _rects;
}

@end
