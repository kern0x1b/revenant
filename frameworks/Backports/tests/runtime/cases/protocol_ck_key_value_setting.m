#import "../app/revenant_check.h"
#import <CloudKit/CloudKit.h>

REVENANT_CASE(protocol_ck_key_value_setting)
{
    CKRecord *record = [[CKRecord alloc] initWithRecordType:@"RevenantProtocolCheck"];
    revenant_expect_true(@"the record conforms to CKRecordKeyValueSetting",
                         [record conformsToProtocol:NSProtocolFromString(@"CKRecordKeyValueSetting")] != (BOOL)negative, @"");
    revenant_expect_true(@"the record responds to both keyed subscript members",
                         ([record respondsToSelector:NSSelectorFromString(@"objectForKeyedSubscript:")]
                          && [record respondsToSelector:NSSelectorFromString(@"setObject:forKeyedSubscript:")]) != (BOOL)negative, @"");
    record[@"key"] = @"value";
    revenant_expect_true(@"a value set through the subscript is read back by the subscript",
                         [record[@"key"] isEqual:@"value"] != (BOOL)negative, @"");
}
