#import <Foundation/Foundation.h>

NSString *const NSExtensionItemsAndErrorsKey = @"NSExtensionItemsAndErrorsKey";

@implementation NSExtensionContext

@synthesize inputItems;

- (NSArray *)inputItems
{
    return inputItems ?: [NSMutableArray array];
}

- (void)completeRequestReturningItems:(NSArray *)items completionHandler:(void (^)(BOOL expired))completionHandler
{
    if (completionHandler) {
        completionHandler(NO);
    }
}

- (void)cancelRequestWithError:(NSError *)error
{
}

- (void)openURL:(NSURL *)URL completionHandler:(void (^)(BOOL success))completionHandler
{
}

@end
