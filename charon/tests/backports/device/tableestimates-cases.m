#import "tableestimates-cases.h"

static NSString *raised(void (^block)(void))
{
    @try {
        block();
    } @catch (NSException *e) {
        return [NSString stringWithFormat:@"%@: %@", e.name, e.reason];
    }
    return @"none";
}

void tableestimates_run(TableEstimatesRecorder record)
{
    for (NSNumber *style in @[@(UITableViewStylePlain), @(UITableViewStyleGrouped)]) {
        UITableView *table = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, 320, 480) style:(UITableViewStyle)style.integerValue];
        NSString *tag = style.integerValue == UITableViewStylePlain ? @"plain" : @"grouped";
        record([tag stringByAppendingString:@" defaults"], [NSString stringWithFormat:@"%g %g %g", table.estimatedRowHeight, table.estimatedSectionHeaderHeight, table.estimatedSectionFooterHeight]);
        table.estimatedRowHeight = 44;
        table.estimatedSectionHeaderHeight = 30;
        table.estimatedSectionFooterHeight = 20;
        record([tag stringByAppendingString:@" kept"], [NSString stringWithFormat:@"%g %g %g", table.estimatedRowHeight, table.estimatedSectionHeaderHeight, table.estimatedSectionFooterHeight]);
        record([tag stringByAppendingString:@" negative row"], raised(^{ table.estimatedRowHeight = -5; }));
        record([tag stringByAppendingString:@" negative header"], raised(^{ table.estimatedSectionHeaderHeight = -5; }));
        record([tag stringByAppendingString:@" negative footer"], raised(^{ table.estimatedSectionFooterHeight = -5; }));
        record([tag stringByAppendingString:@" kept after refusal"], [NSString stringWithFormat:@"%g %g %g", table.estimatedRowHeight, table.estimatedSectionHeaderHeight, table.estimatedSectionFooterHeight]);
        [table setValue:@55 forKey:@"estimatedRowHeight"];
        record([tag stringByAppendingString:@" by key"], [NSString stringWithFormat:@"%g %@", table.estimatedRowHeight, [table valueForKey:@"estimatedRowHeight"]]);
        table.estimatedRowHeight = UITableViewAutomaticDimension;
        record([tag stringByAppendingString:@" automatic"], [NSString stringWithFormat:@"%g", table.estimatedRowHeight]);
        table.estimatedRowHeight = 0;
        record([tag stringByAppendingString:@" zero"], [NSString stringWithFormat:@"%g", table.estimatedRowHeight]);
    }
}
