#import "CharonSearch.h"

@implementation UISearchToken {
@private
    NSString *_text;
    UIImage *_icon;
    id _representedObject;
}

+ (UISearchToken *)tokenWithIcon:(UIImage *)icon text:(NSString *)text
{
    return [[self alloc] initCharonWithIcon:icon text:text];
}

- (instancetype)initCharonWithIcon:(UIImage *)icon text:(NSString *)text
{
    if ((self = [super init])) {
        _icon = icon;
        _text = [text copy];
    }
    return self;
}

- (id)representedObject
{
    return _representedObject;
}

- (void)setRepresentedObject:(id)representedObject
{
    _representedObject = representedObject;
}

- (NSString *)charon_text
{
    return _text;
}

- (UIImage *)charon_icon
{
    return _icon;
}

@end
