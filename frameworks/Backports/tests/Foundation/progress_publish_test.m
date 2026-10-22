#import "check.h"

static void revenant_publish(NSProgress *progress, SEL selector)
{
    REVENANT_IMP(NSProgress, selector, void (*)(id, SEL))(progress, selector);
}

static id revenant_subscribe(NSURL *url, NSProgressPublishingHandler handler)
{
    SEL selector = @selector(addSubscriberForFileURL:withPublishingHandler:);
    return REVENANT_CLASS_IMP(NSProgress, selector, id (*)(id, SEL, NSURL *, NSProgressPublishingHandler))([NSProgress class], selector, url, handler);
}

static void revenant_unsubscribe(id subscriber)
{
    SEL selector = @selector(removeSubscriber:);
    REVENANT_CLASS_IMP(NSProgress, selector, void (*)(id, SEL, id))([NSProgress class], selector, subscriber);
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    NSURL *url = [NSURL fileURLWithPath:@"/tmp/revenant-progress-file"];
    NSProgress *progress = [[NSProgress alloc] initWithParent:nil userInfo:@{NSProgressFileURLKey: url}];
    __block int published = 0, unpublished = 0;
    id subscriber = revenant_subscribe(url, ^NSProgressUnpublishingHandler(NSProgress *seen) {
        published++;
        return ^{
            unpublished++;
        };
    });
    revenant_check(published == 0, "nothing is published before publish", [NSString stringWithFormat:@"%d", published]);
    revenant_publish(progress, @selector(publish));
    revenant_check(published == 1, "publishing calls the subscriber's handler", [NSString stringWithFormat:@"%d", published]);
    revenant_publish(progress, @selector(unpublish));
    revenant_check(unpublished == (revenant_negative ? 2 : 1), "unpublishing calls the unpublishing handler", [NSString stringWithFormat:@"%d", unpublished]);
    revenant_publish(progress, @selector(publish));
    __block int late = 0;
    id later = revenant_subscribe(url, ^NSProgressUnpublishingHandler(NSProgress *seen) {
        late++;
        return nil;
    });
    revenant_check(late == 1, "a new subscriber is told about progress already published", [NSString stringWithFormat:@"%d", late]);
    revenant_unsubscribe(subscriber);
    revenant_unsubscribe(later);
    revenant_publish(progress, @selector(unpublish));
    revenant_publish(progress, @selector(publish));
    revenant_check(published == 2 && late == 1, "removed subscribers hear nothing more", [NSString stringWithFormat:@"%d %d", published, late]);
    revenant_publish(progress, @selector(unpublish));
    NSProgress *bare = [[NSProgress alloc] initWithParent:nil userInfo:nil];
    BOOL raised = NO;
    @try {
        revenant_publish(bare, @selector(publish));
    } @catch (NSException *exception) {
        raised = [exception.name isEqualToString:NSInvalidArgumentException];
    }
    revenant_check(raised, "a progress without a file URL cannot be published", @"published");
    return revenant_finish();
}
