#include "../revenant_impl.h"
#import <Foundation/Foundation.h>

NSString *const BACKPORT_IMPL(NSExtensionItemAttributedTitleKey) = @"NSExtensionItemAttributedTitleKey";
NSString *const BACKPORT_IMPL(NSExtensionItemAttributedContentTextKey) = @"NSExtensionItemAttributedContentTextKey";
NSString *const BACKPORT_IMPL(NSExtensionItemAttachmentsKey) = @"NSExtensionItemAttachmentsKey";

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

- (id)revenant_valueForKey:(NSString *)key
{
    return _userInfo[key];
}

- (void)revenant_setValue:(id)value forKey:(NSString *)key
{
    NSMutableDictionary *info = _userInfo ? [_userInfo mutableCopy] : [NSMutableDictionary dictionary];
    if (value)
        info[key] = value;
    else
        [info removeObjectForKey:key];
    _userInfo = [info copy];
}

- (NSAttributedString *)revenant_attributedStringForKey:(NSString *)key
{
    NSData *data = [self revenant_valueForKey:key];
    return [data isKindOfClass:[NSData class]] ? [NSKeyedUnarchiver unarchiveObjectWithData:data] : nil;
}

- (NSAttributedString *)attributedTitle
{
    return [self revenant_attributedStringForKey:BACKPORT_IMPL(NSExtensionItemAttributedTitleKey)];
}

- (void)setAttributedTitle:(NSAttributedString *)title
{
    [self revenant_setValue:title ? [NSKeyedArchiver archivedDataWithRootObject:title] : nil forKey:BACKPORT_IMPL(NSExtensionItemAttributedTitleKey)];
}

- (NSAttributedString *)attributedContentText
{
    return [self revenant_attributedStringForKey:BACKPORT_IMPL(NSExtensionItemAttributedContentTextKey)];
}

- (void)setAttributedContentText:(NSAttributedString *)text
{
    [self revenant_setValue:text ? [NSKeyedArchiver archivedDataWithRootObject:text] : nil forKey:BACKPORT_IMPL(NSExtensionItemAttributedContentTextKey)];
}

- (NSArray<NSItemProvider *> *)attachments
{
    return [self revenant_valueForKey:BACKPORT_IMPL(NSExtensionItemAttachmentsKey)];
}

- (void)setAttachments:(NSArray<NSItemProvider *> *)attachments
{
    [self revenant_setValue:[attachments copy] forKey:BACKPORT_IMPL(NSExtensionItemAttachmentsKey)];
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
