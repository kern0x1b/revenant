#import <Foundation/Foundation.h>

NSString *const NSExtensionItemAttributedTitleKey = @"NSExtensionItemAttributedTitleKey";
NSString *const NSExtensionItemAttributedContentTextKey = @"NSExtensionItemAttributedContentTextKey";
NSString *const NSExtensionItemAttachmentsKey = @"NSExtensionItemAttachmentsKey";

@implementation NSExtensionItem {
    NSDictionary *_userInfo;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)init
{
    self = [super init];
    if (self)
        _userInfo = @{};
    return self;
}

- (id)charon_valueForKey:(NSString *)key
{
    return _userInfo[key];
}

- (void)charon_setValue:(id)value forKey:(NSString *)key
{
    NSMutableDictionary *info = _userInfo ? [_userInfo mutableCopy] : [NSMutableDictionary dictionary];
    if (value)
        info[key] = value;
    else
        [info removeObjectForKey:key];
    _userInfo = [info copy];
}

- (NSAttributedString *)charon_attributedStringForKey:(NSString *)key
{
    NSData *data = [self charon_valueForKey:key];
    return [data isKindOfClass:[NSData class]] ? [NSKeyedUnarchiver unarchiveObjectWithData:data] : nil;
}

- (NSAttributedString *)attributedTitle
{
    return [self charon_attributedStringForKey:NSExtensionItemAttributedTitleKey];
}

- (void)setAttributedTitle:(NSAttributedString *)title
{
    [self charon_setValue:title ? [NSKeyedArchiver archivedDataWithRootObject:title] : nil forKey:NSExtensionItemAttributedTitleKey];
}

- (NSAttributedString *)attributedContentText
{
    return [self charon_attributedStringForKey:NSExtensionItemAttributedContentTextKey];
}

- (void)setAttributedContentText:(NSAttributedString *)text
{
    [self charon_setValue:text ? [NSKeyedArchiver archivedDataWithRootObject:text] : nil forKey:NSExtensionItemAttributedContentTextKey];
}

- (NSArray<NSItemProvider *> *)attachments
{
    return [self charon_valueForKey:NSExtensionItemAttachmentsKey];
}

- (void)setAttachments:(NSArray<NSItemProvider *> *)attachments
{
    [self charon_setValue:[attachments copy] forKey:NSExtensionItemAttachmentsKey];
}

- (NSDictionary *)userInfo
{
    return _userInfo;
}

- (void)setUserInfo:(NSDictionary *)userInfo
{
    _userInfo = [userInfo copy];
}

- (id)copyWithZone:(NSZone *)zone
{
    NSExtensionItem *copy = [[[self class] alloc] init];
    copy->_userInfo = [_userInfo copy];
    return copy;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_userInfo forKey:@"NSExtensionItemUserInfoKey"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self)
        _userInfo = [coder decodeObjectOfClasses:[NSSet setWithObjects:[NSDictionary class], [NSString class], [NSNumber class], [NSArray class], [NSData class], [NSDate class], [NSItemProvider class], nil] forKey:@"NSExtensionItemUserInfoKey"];
    return self;
}

@end
