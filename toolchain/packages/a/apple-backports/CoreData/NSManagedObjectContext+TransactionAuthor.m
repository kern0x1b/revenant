#import <CoreData/CoreData.h>
#import <objc/runtime.h>

static const char RevenantTransactionAuthorKey;

@implementation NSManagedObjectContext (RevenantTransactionAuthor)

- (NSString *)transactionAuthor
{
    return objc_getAssociatedObject(self, &RevenantTransactionAuthorKey);
}

- (void)setTransactionAuthor:(NSString *)author
{
    objc_setAssociatedObject(self, &RevenantTransactionAuthorKey, author, OBJC_ASSOCIATION_COPY);
}

@end
