#ifndef CHARON_CK_IOS26_H
#define CHARON_CK_IOS26_H

#import <Foundation/Foundation.h>
#import <CloudKit/CloudKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface CKShareRequestAccessOperation : CKOperation

- (instancetype)initWithShareURLs:(NSArray<NSURL *> *)shareURLs NS_SWIFT_NAME(init(shareURLs:));

@property (nullable, copy, nonatomic) NSArray<NSURL *> *shareURLs;

@property (nullable, copy, nonatomic) void (^perShareAccessRequestCompletionBlock)(NSURL *shareURL,
                                                                                  NSError *_Nullable shareRequestAccessError) NS_REFINED_FOR_SWIFT;

@property (nullable, copy, nonatomic) void (^shareRequestAccessCompletionBlock)(NSError *_Nullable operationError) NS_REFINED_FOR_SWIFT;

@end

NS_ASSUME_NONNULL_END

#endif
