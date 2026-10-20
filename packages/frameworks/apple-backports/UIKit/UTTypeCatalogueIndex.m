#import <Foundation/Foundation.h>
#import "RevenantUTType.h"

static NSMutableArray *revenant_uttype_catalogue;

void revenant_uttype_catalogue_add(NSArray *types)
{
    if (!types.count)
        return;
    if (!revenant_uttype_catalogue)
        revenant_uttype_catalogue = [[NSMutableArray alloc] init];
    [revenant_uttype_catalogue addObjectsFromArray:types];
}

NSArray *revenant_uttype_catalogue_types(void)
{
    return revenant_uttype_catalogue ? [revenant_uttype_catalogue copy] : @[];
}
