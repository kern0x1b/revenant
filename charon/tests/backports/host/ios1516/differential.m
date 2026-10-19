#import <Foundation/Foundation.h>

@interface NSUUID (CharonHostCompare)
- (NSComparisonResult)charonHostCompare:(NSUUID *)otherUUID;
@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        NSArray *fixed = @[@"00000000-0000-0000-0000-000000000000", @"00000000-0000-0000-0000-000000000001", @"00000000-0000-0000-0000-000000000100",
                           @"00000001-0000-0000-0000-000000000000", @"80000000-0000-0000-0000-000000000000", @"7FFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF",
                           @"FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFE", @"FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF", @"E2C56DB5-DFFB-48D2-B060-D0F5A71096E0",
                           @"E2C56DB5-DFFB-48D2-B060-D0F5A71096E1", @"01000000-0000-0000-0000-000000000000", @"00010000-0000-0000-0000-000000000000"];
        NSMutableArray *ids = [NSMutableArray array];
        for (NSString *string in fixed)
            [ids addObject:[[NSUUID alloc] initWithUUIDString:string]];
        for (int index = 0; index < 12; index++)
            [ids addObject:[NSUUID UUID]];
        NSUInteger count = ids.count, wrong = 0;
        NSMutableString *header = [NSMutableString stringWithString:@"static const char *const charon_uuid_strings[] = {\n"];
        for (NSUUID *uuid in ids)
            [header appendFormat:@"    \"%@\",\n", uuid.UUIDString];
        [header appendFormat:@"};\nstatic const int charon_uuid_count = %lu;\nstatic const signed char charon_uuid_orders[%lu][%lu] = {\n", (unsigned long)count, (unsigned long)count, (unsigned long)count];
        for (NSUUID *first in ids) {
            [header appendString:@"    {"];
            for (NSUUID *second in ids) {
                NSComparisonResult system = [first compare:second];
                if (system != [first charonHostCompare:second])
                    wrong++;
                [header appendFormat:@"%ld,", (long)system];
            }
            [header appendString:@"},\n"];
        }
        [header appendString:@"};\nstatic const signed char charon_uuid_against_nil[] = {"];
        NSUUID *none = nil;
        for (NSUUID *first in ids) {
            NSComparisonResult system = [first compare:none];
            if (system != [first charonHostCompare:none])
                wrong++;
            [header appendFormat:@"%ld,", (long)system];
        }
        [header appendString:@"};\n"];
        printf("%lu pairs and %lu against nil, %lu differ from the system\n", (unsigned long)(count * count), (unsigned long)count, (unsigned long)wrong);
        if (wrong)
            return 1;
        if (argc > 1)
            [header writeToFile:@(argv[1]) atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    }
    return 0;
}
