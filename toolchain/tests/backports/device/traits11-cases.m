#import "traits11-cases.h"

static NSString *traits(id<UITextInputTraits> input)
{
    return [NSString stringWithFormat:@"%ld %ld %ld %d", (long)input.smartQuotesType, (long)input.smartDashesType, (long)input.smartInsertDeleteType, input.passwordRules == nil];
}

static NSString *insets(UIEdgeInsets i)
{
    return [NSString stringWithFormat:@"(%g %g %g %g)", i.top, i.left, i.bottom, i.right];
}

static NSString *indicators(UIScrollView *view)
{
    return [NSString stringWithFormat:@"vertical=%@ horizontal=%@", insets(view.verticalScrollIndicatorInsets), insets(view.horizontalScrollIndicatorInsets)];
}

static void indicator_insets(Traits11Recorder record)
{
    UIScrollView *view = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, 200, 300)];
    record(@"indicators.default", indicators(view));
    view.scrollIndicatorInsets = UIEdgeInsetsMake(1, 2, 3, 4);
    record(@"indicators.base", indicators(view));
    view.verticalScrollIndicatorInsets = UIEdgeInsetsMake(5, 6, 7, 8);
    record(@"indicators.vertical", indicators(view));
    view.horizontalScrollIndicatorInsets = UIEdgeInsetsMake(9, 10, 11, 12);
    record(@"indicators.horizontal", indicators(view));
    view.scrollIndicatorInsets = UIEdgeInsetsMake(13, 14, 15, 16);
    record(@"indicators.reset", indicators(view));
    view.horizontalScrollIndicatorInsets = UIEdgeInsetsMake(0, 20, 0, 0);
    record(@"indicators.horizontal.only", indicators(view));
    view.verticalScrollIndicatorInsets = UIEdgeInsetsZero;
    record(@"indicators.zero", indicators(view));
    UIScrollView *other = [[UIScrollView alloc] initWithFrame:CGRectZero];
    record(@"indicators.separate", indicators(other));
    UITableView *table = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, 200, 300)];
    table.verticalScrollIndicatorInsets = UIEdgeInsetsMake(0, 0, 49, 0);
    record(@"indicators.table", indicators(table));
    table.scrollIndicatorInsets = UIEdgeInsetsMake(0, 0, 10, 0);
    record(@"indicators.table.reset", indicators(table));
}

void traits11_run(UIWindow *window, Traits11Recorder record)
{
    indicator_insets(record);
    NSArray *inputs = @[[[UITextField alloc] initWithFrame:CGRectMake(0, 0, 100, 30)], [[UITextView alloc] initWithFrame:CGRectMake(0, 0, 100, 30)], [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, 200, 44)]];
    NSArray *names = @[@"field", @"text", @"search"];
    for (NSUInteger index = 0; index < inputs.count; index++) {
        id<UITextInputTraits> input = inputs[index];
        NSString *name = names[index];
        record([name stringByAppendingString:@".default"], traits(input));
        input.smartQuotesType = UITextSmartQuotesTypeNo;
        input.smartDashesType = UITextSmartDashesTypeYes;
        input.smartInsertDeleteType = UITextSmartInsertDeleteTypeNo;
        record([name stringByAppendingString:@".set"], traits(input));
        input.smartQuotesType = UITextSmartQuotesTypeYes;
        record([name stringByAppendingString:@".again"], traits(input));
        input.smartQuotesType = UITextSmartQuotesTypeDefault;
        input.smartDashesType = UITextSmartDashesTypeDefault;
        input.smartInsertDeleteType = UITextSmartInsertDeleteTypeDefault;
        record([name stringByAppendingString:@".reset"], traits(input));
    }
    UITextField *first = inputs[0], *second = [[UITextField alloc] initWithFrame:CGRectZero];
    first.smartDashesType = UITextSmartDashesTypeYes;
    record(@"separate", [NSString stringWithFormat:@"%ld %ld", (long)first.smartDashesType, (long)second.smartDashesType]);
    record(@"values", [NSString stringWithFormat:@"%ld %ld %ld | %ld %ld %ld | %ld %ld %ld", (long)UITextSmartQuotesTypeDefault, (long)UITextSmartQuotesTypeNo, (long)UITextSmartQuotesTypeYes,
                       (long)UITextSmartDashesTypeDefault, (long)UITextSmartDashesTypeNo, (long)UITextSmartDashesTypeYes, (long)UITextSmartInsertDeleteTypeDefault, (long)UITextSmartInsertDeleteTypeNo, (long)UITextSmartInsertDeleteTypeYes]);

    UITextInputPasswordRules *rules = [UITextInputPasswordRules passwordRulesWithDescriptor:@"minlength: 8; required: lower; required: upper; required: digit;"];
    record(@"rules", [NSString stringWithFormat:@"%@ %d", rules.passwordRulesDescriptor, [rules isKindOfClass:[UITextInputPasswordRules class]]]);
    UITextInputPasswordRules *copy = [rules copy];
    record(@"rules.copy", [NSString stringWithFormat:@"%d %d %@ %d", copy != rules, [copy isEqual:rules], copy.passwordRulesDescriptor, 0]);
    UITextInputPasswordRules *other = [UITextInputPasswordRules passwordRulesWithDescriptor:@"maxlength: 16;"];
    record(@"rules.equal", [NSString stringWithFormat:@"%d %d %d %d", [rules isEqual:other], [rules isEqual:nil], [rules isEqual:@"x"], [rules isEqual:rules]]);
    NSString *description = rules.description;
    record(@"rules.description", [NSString stringWithFormat:@"%d %d %d", [description hasPrefix:@"<"], [description hasSuffix:@">"], [description rangeOfString:@"; passwordRulesDescriptor = minlength: 8;"].location != NSNotFound]);
    NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:rules requiringSecureCoding:YES error:NULL];
    UITextInputPasswordRules *decoded = archive ? [NSKeyedUnarchiver unarchivedObjectOfClass:[UITextInputPasswordRules class] fromData:archive error:NULL] : nil;
    record(@"rules.coding", [NSString stringWithFormat:@"%d %@ %d", decoded != nil, decoded.passwordRulesDescriptor, [UITextInputPasswordRules supportsSecureCoding]]);
    for (NSUInteger index = 0; index < inputs.count; index++) {
        id<UITextInputTraits> input = inputs[index];
        input.passwordRules = rules;
        record([names[index] stringByAppendingString:@".rules"], [NSString stringWithFormat:@"%d %d %d", input.passwordRules != nil, [input.passwordRules isEqual:rules], input.passwordRules != rules]);
        input.passwordRules = nil;
        record([names[index] stringByAppendingString:@".rules.nil"], [NSString stringWithFormat:@"%d", input.passwordRules == nil]);
    }

    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
    record(@"invert.default", [NSString stringWithFormat:@"%d", view.accessibilityIgnoresInvertColors]);
    view.accessibilityIgnoresInvertColors = YES;
    UIView *label = [[UILabel alloc] init];
    record(@"invert.set", [NSString stringWithFormat:@"%d %d", view.accessibilityIgnoresInvertColors, label.accessibilityIgnoresInvertColors]);
    view.accessibilityIgnoresInvertColors = NO;
    record(@"invert.reset", [NSString stringWithFormat:@"%d", view.accessibilityIgnoresInvertColors]);

    UIScreen *screen = [UIScreen mainScreen];
    record(@"captured", [NSString stringWithFormat:@"%d %@", screen.captured, UIScreenCapturedDidChangeNotification]);
    __block int posted = 0;
    id token = [[NSNotificationCenter defaultCenter] addObserverForName:UIScreenCapturedDidChangeNotification object:nil queue:nil usingBlock:^(NSNotification *note) { posted++; }];
    [[NSNotificationCenter defaultCenter] postNotificationName:UIScreenDidConnectNotification object:screen];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
    [[NSNotificationCenter defaultCenter] removeObserver:token];
    record(@"captured.quiet", [NSString stringWithFormat:@"%d %d", posted, screen.captured]);
}
