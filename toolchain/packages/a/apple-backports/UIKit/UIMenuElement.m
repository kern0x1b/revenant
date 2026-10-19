#import "CharonMenus.h"

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

NSString *charon_menu_attributes_text(NSUInteger attributes)
{
    NSMutableArray *names = [NSMutableArray array];
    if (attributes & 1)
        [names addObject:@"Disabled"];
    if (attributes & 2)
        [names addObject:@"Destructive"];
    if (attributes & 4)
        [names addObject:@"Hidden"];
    if (attributes & 8)
        [names addObject:@"KeepsMenuPresented"];
    return [NSString stringWithFormat:@"(%@)", [names componentsJoinedByString:@"|"]];
}

@implementation UIMenuElement {
@private
    NSString *_title;
    UIImage *_image;
    NSString *_subtitle;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initCharonWithTitle:(NSString *)title image:(UIImage *)image
{
    if ((self = [super init])) {
        _title = [title copy];
        _image = image;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [self initCharonWithTitle:[coder decodeObjectOfClass:[NSString class] forKey:@"title"]
                                image:[coder decodeObjectOfClass:[UIImage class] forKey:@"image"]];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInteger:0 forKey:@"preferredDisplayMode"];
    if (_title)
        [coder encodeObject:_title forKey:@"title"];
    if (_image)
        [coder encodeObject:_image forKey:@"image"];
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (NSString *)title
{
    return _title;
}

- (UIImage *)image
{
    return _image;
}

- (NSString *)subtitle
{
    return _subtitle;
}

- (void)setSubtitle:(NSString *)subtitle
{
    _subtitle = [subtitle copy];
}

- (void)charon_setTitle:(NSString *)title
{
    _title = [title copy];
}

- (void)charon_setImage:(UIImage *)image
{
    _image = image;
}

@end
