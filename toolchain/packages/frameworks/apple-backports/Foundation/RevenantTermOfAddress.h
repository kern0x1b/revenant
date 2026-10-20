#import <Foundation/Foundation.h>

#if !defined(__IPHONE_17_0)

NS_ASSUME_NONNULL_BEGIN

@interface NSTermOfAddress : NSObject <NSCopying, NSSecureCoding>

+ (instancetype)neutral;
+ (instancetype)feminine;
+ (instancetype)masculine;

+ (instancetype)currentUser;

+ (instancetype)localizedForLanguageIdentifier:(NSString*)language
                                  withPronouns:(NSArray *)pronouns;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

@property(nullable, readonly, copy) NSString* languageIdentifier;
@property(nullable, readonly, copy) NSArray *pronouns;
@end

NS_ASSUME_NONNULL_END

#endif
