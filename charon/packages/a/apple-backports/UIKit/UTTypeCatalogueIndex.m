#import <Foundation/Foundation.h>
#import "CharonUTType.h"

static NSMutableArray *charon_uttype_catalogue;

void charon_uttype_catalogue_add(NSArray *types)
{
    if (!types.count)
        return;
    if (!charon_uttype_catalogue)
        charon_uttype_catalogue = [[NSMutableArray alloc] init];
    [charon_uttype_catalogue addObjectsFromArray:types];
}

NSArray *charon_uttype_catalogue_types(void)
{
    return charon_uttype_catalogue ? [charon_uttype_catalogue copy] : @[];
}
