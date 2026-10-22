#import "check.h"

NSArray *revenant_metadata_urls(NSArray *items);

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    NSURL *url = [NSURL fileURLWithPath:@"/tmp/a.txt"];
    NSArray *urls = revenant_metadata_urls(@[url, @"/tmp/b.txt", @"/tmp/c.txt", [NSURL URLWithString:@"https://example.com/"], @42]);
    NSArray *expected = revenant_negative ? @[url] : @[url, [NSURL fileURLWithPath:@"/tmp/b.txt"], [NSURL fileURLWithPath:@"/tmp/c.txt"]];
    revenant_check([urls isEqualToArray:expected], "URLs and paths become file URLs and the rest is dropped", [NSString stringWithFormat:@"%@", urls]);
    NSMetadataQuery *query = [[NSMetadataQuery alloc] init];
    NSArray *items = @[url, @"/tmp/b.txt"];
    SEL setItems = @selector(setSearchItems:);
    SEL getItems = @selector(searchItems);
    REVENANT_IMP(NSMetadataQuery, setItems, void (*)(id, SEL, NSArray *))(query, setItems, items);
    revenant_check([REVENANT_IMP(NSMetadataQuery, getItems, NSArray *(*)(id, SEL))(query, getItems) isEqualToArray:items], "the getter returns what was set", @"differs");
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    SEL setQueue = @selector(setOperationQueue:);
    SEL getQueue = @selector(operationQueue);
    REVENANT_IMP(NSMetadataQuery, setQueue, void (*)(id, SEL, NSOperationQueue *))(query, setQueue, queue);
    revenant_check(REVENANT_IMP(NSMetadataQuery, getQueue, NSOperationQueue *(*)(id, SEL))(query, getQueue) == queue, "the operation queue is kept", @"differs");
    return revenant_finish();
}
