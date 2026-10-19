#import "CharonCoreData.h"

@implementation NSMergePolicy (CharonPolicies)

+ (NSMergePolicy *)errorMergePolicy
{
    return NSErrorMergePolicy;
}

+ (NSMergePolicy *)rollbackMergePolicy
{
    return NSRollbackMergePolicy;
}

+ (NSMergePolicy *)overwriteMergePolicy
{
    return NSOverwriteMergePolicy;
}

+ (NSMergePolicy *)mergeByPropertyObjectTrumpMergePolicy
{
    return NSMergeByPropertyObjectTrumpMergePolicy;
}

+ (NSMergePolicy *)mergeByPropertyStoreTrumpMergePolicy
{
    return NSMergeByPropertyStoreTrumpMergePolicy;
}

@end
