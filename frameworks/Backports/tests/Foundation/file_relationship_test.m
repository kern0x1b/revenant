#import "check.h"

static NSString *revenant_relationship_name(NSURLRelationship relationship)
{
    switch (relationship) {
        case NSURLRelationshipContains: return @"contains";
        case NSURLRelationshipSame: return @"same";
        case NSURLRelationshipOther: return @"other";
    }
    return @"unknown";
}

static BOOL revenant_relationship(NSURL *directory, NSURL *item, NSURLRelationship *relationship)
{
    return [[NSFileManager defaultManager] getRelationship:relationship ofDirectoryAtURL:directory toItemAtURL:item error:nil];
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    NSFileManager *manager = [NSFileManager defaultManager];
    NSString *root = [NSTemporaryDirectory() stringByAppendingPathComponent:
                      [NSString stringWithFormat:@"revenant-relationship-%d", [NSProcessInfo processInfo].processIdentifier]];
    [manager createDirectoryAtPath:[root stringByAppendingPathComponent:@"a/b"] withIntermediateDirectories:YES attributes:nil error:nil];
    [@"x" writeToFile:[root stringByAppendingPathComponent:@"a/b/c.txt"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    [@"y" writeToFile:[root stringByAppendingPathComponent:@"other.txt"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    NSURL *base = [NSURL fileURLWithPath:root isDirectory:YES];
    NSURL *directory = [base URLByAppendingPathComponent:@"a" isDirectory:YES];
    NSURL *inside = [directory URLByAppendingPathComponent:@"b/c.txt"];
    NSURL *other = [base URLByAppendingPathComponent:@"other.txt"];
    NSURL *file = [directory URLByAppendingPathComponent:@"b/c.txt"];
    NSURLRelationship relationship = NSURLRelationshipOther;

    BOOL contains = revenant_relationship(directory, inside, &relationship);
    revenant_check(contains && relationship == (revenant_negative ? NSURLRelationshipSame : NSURLRelationshipContains),
                   "a directory contains an item below it", revenant_relationship_name(relationship));
    BOOL same = revenant_relationship(directory, directory, &relationship);
    revenant_check(same && relationship == NSURLRelationshipSame, "a directory is the same as itself", revenant_relationship_name(relationship));
    BOOL sibling = revenant_relationship(directory, other, &relationship);
    revenant_check(sibling && relationship == NSURLRelationshipOther, "a directory does not contain a sibling", revenant_relationship_name(relationship));
    BOOL notDirectory = revenant_relationship(file, directory, &relationship);
    revenant_check(notDirectory && relationship == NSURLRelationshipOther, "a file is not a directory that contains its parent", revenant_relationship_name(relationship));

    NSError *error = nil;
    NSURL *missing = [base URLByAppendingPathComponent:@"missing" isDirectory:YES];
    BOOL answered = [manager getRelationship:&relationship ofDirectoryAtURL:missing toItemAtURL:inside error:&error];
    revenant_check(!answered && error != nil, "a missing directory is an error", @"answered without an error");

    BOOL domain = [manager getRelationship:&relationship ofDirectory:NSDocumentDirectory inDomain:0 toItemAtURL:inside error:nil];
    revenant_check(domain && relationship == NSURLRelationshipOther, "an item outside the domain's directories is other", revenant_relationship_name(relationship));

    [manager removeItemAtPath:root error:nil];
    return revenant_finish();
}
