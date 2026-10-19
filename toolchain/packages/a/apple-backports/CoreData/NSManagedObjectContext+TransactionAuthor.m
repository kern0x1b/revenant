#import <CoreData/CoreData.h>
#import <objc/runtime.h>

static const char CharonTransactionAuthorKey;

@implementation NSManagedObjectContext (CharonTransactionAuthor)

- (NSString *)transactionAuthor
{
    return objc_getAssociatedObject(self, &CharonTransactionAuthorKey);
}

- (void)setTransactionAuthor:(NSString *)author
{
    objc_setAssociatedObject(self, &CharonTransactionAuthorKey, author, OBJC_ASSOCIATION_COPY);
}

@end
