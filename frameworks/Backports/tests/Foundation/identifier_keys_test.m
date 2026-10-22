#import "check.h"

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    revenant_expect_string("the morphology attribute name", NSMorphologyAttributeName, revenant_negative ? @"NSMorphologyX" : @"NSMorphology");
    revenant_expect_string("the localized number format attribute name", NSLocalizedNumberFormatAttributeName, @"NSLocalizedNumberFormat");
    revenant_expect_string("the list item delimiter attribute name", NSListItemDelimiterAttributeName, @"NSListItemDelimiter");
    revenant_expect_string("the excluded from sync key", NSURLUbiquitousItemIsExcludedFromSyncKey, @"NSURLUbiquitousItemIsExcludedFromSyncKey");
    revenant_expect_string("the upload resume data key", NSURLSessionUploadTaskResumeData, @"NSURLSessionUploadTaskResumeData");
    NSLocalizedNumberFormatRule *automatic = [NSLocalizedNumberFormatRule automatic];
    revenant_check(automatic != nil && automatic == [NSLocalizedNumberFormatRule automatic], "the automatic rule is one shared object", @"not shared");
    revenant_check([automatic isEqual:[automatic copy]], "a copy equals the rule", @"not equal");
    NSLocalizedNumberFormatRule *decoded = [[NSLocalizedNumberFormatRule alloc] initWithCoder:[[NSKeyedUnarchiver alloc] initForReadingFromData:[NSKeyedArchiver archivedDataWithRootObject:@1 requiringSecureCoding:YES error:NULL] error:NULL]];
    revenant_check(decoded == automatic, "a decoded rule is the shared one", [NSString stringWithFormat:@"%@", decoded]);
    return revenant_finish();
}
