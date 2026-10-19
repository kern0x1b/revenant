#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class NSTextContentStorage;

@interface CharonTextLocation : NSObject <NSTextLocation>

@property (nonatomic, readonly, weak) NSTextContentStorage *textContentStorage;
@property (nonatomic, readonly) NSInteger offset;

+ (instancetype)locationWithTextContentStorage:(NSTextContentStorage *)textContentStorage offset:(NSInteger)offset;
- (instancetype)initWithTextContentStorage:(NSTextContentStorage *)textContentStorage offset:(NSInteger)offset;

@end

NS_ASSUME_NONNULL_END
