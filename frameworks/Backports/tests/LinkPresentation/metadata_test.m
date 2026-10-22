#import "../Foundation/check.h"
#import <LinkPresentation/LinkPresentation.h>
#import <arpa/inet.h>
#import <netinet/in.h>
#import <pthread.h>
#import <sys/socket.h>
#import <unistd.h>

static NSString *revenant_fixture_path(void)
{
    return [[[NSString stringWithUTF8String:__FILE__] stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"page.html"];
}

static NSData *revenant_served_page;

static void *revenant_serve(void *context)
{
    int listener = (int)(intptr_t)context;
    for (;;) {
        @autoreleasepool {
            int client = accept(listener, NULL, NULL);
            if (client < 0) {
                continue;
            }
            char request[8192];
            (void)read(client, request, sizeof request);
            NSData *head = [@"HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nConnection: close\r\nContent-Length: " dataUsingEncoding:NSASCIIStringEncoding];
            NSData *length = [[NSString stringWithFormat:@"%lu\r\n\r\n", (unsigned long)revenant_served_page.length] dataUsingEncoding:NSASCIIStringEncoding];
            (void)write(client, head.bytes, head.length);
            (void)write(client, length.bytes, length.length);
            (void)write(client, revenant_served_page.bytes, revenant_served_page.length);
            close(client);
        }
    }
    return NULL;
}

static NSURL *revenant_start_server(void)
{
    revenant_served_page = [NSData dataWithContentsOfFile:revenant_fixture_path()];
    int listener = socket(AF_INET, SOCK_STREAM, 0);
    struct sockaddr_in address;
    memset(&address, 0, sizeof address);
    address.sin_len = sizeof address;
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    address.sin_port = 0;
    revenant_check(bind(listener, (struct sockaddr *)&address, sizeof address) == 0 && listen(listener, 8) == 0, "loopback server listens", @"bind or listen failed");
    socklen_t length = sizeof address;
    getsockname(listener, (struct sockaddr *)&address, &length);
    pthread_t thread;
    pthread_create(&thread, NULL, revenant_serve, (void *)(intptr_t)listener);
    pthread_detach(thread);
    return [NSURL URLWithString:[NSString stringWithFormat:@"http://127.0.0.1:%u/page.html", ntohs(address.sin_port)]];
}

static BOOL revenant_wait(BOOL *finished)
{
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:30];
    while (!*finished && [deadline timeIntervalSinceNow] > 0) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }
    return *finished;
}

static id revenant_fetch(id provider, NSURL *url, NSError **error)
{
    __block id result = nil;
    __block NSError *failure = nil;
    __block BOOL finished = NO;
    [provider startFetchingMetadataForURL:url completionHandler:^(id metadata, NSError *fetchError) {
        result = metadata;
        failure = fetchError;
        finished = YES;
    }];
    revenant_wait(&finished);
    *error = failure;
    return result;
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    Class providerClass = NSClassFromString(@"LPMetadataProviderRevenant");
    Class metadataClass = NSClassFromString(@"LPLinkMetadataRevenant");
    revenant_check((providerClass != Nil) != revenant_negative, "LPMetadataProvider implementation is present", NSStringFromClass(providerClass));
    revenant_check((metadataClass != Nil) != revenant_negative, "LPLinkMetadata implementation is present", NSStringFromClass(metadataClass));
    if (!providerClass || !metadataClass) {
        return revenant_finish();
    }

    NSURL *url = revenant_start_server();
    NSError *hostError = nil;
    NSError *backportError = nil;
    LPMetadataProvider *hostProvider = [[LPMetadataProvider alloc] init];
    LPLinkMetadata *hostMetadata = revenant_fetch(hostProvider, url, &hostError);
    id provider = [[providerClass alloc] init];
    id backportMetadata = revenant_fetch(provider, url, &backportError);
    revenant_check(backportError == nil && backportMetadata != nil, "backport fetches the fixture page", [NSString stringWithFormat:@"%@", backportError]);
    if (!backportMetadata) {
        return revenant_finish();
    }
    revenant_check(hostMetadata != nil, "host fetches the fixture page", [NSString stringWithFormat:@"%@", hostError]);
    revenant_expect_string("title is the og:title with entities decoded", [backportMetadata valueForKey:@"title"], @"Open \"Graph\" title");
    revenant_expect_string("URL is og:url", [[backportMetadata valueForKey:@"URL"] absoluteString], @"https://example.com/canonical");
    revenant_expect_string("remote video URL is og:video", [[backportMetadata valueForKey:@"remoteVideoURL"] absoluteString], @"https://example.com/clip.mp4");
    revenant_expect_string("summary is og:description with a numeric entity", [backportMetadata valueForKey:@"_summary"], @"OG summary A");
    revenant_expect_string("originalURL is the requested URL", [[backportMetadata valueForKey:@"originalURL"] absoluteString], [url absoluteString]);
    if (hostMetadata) {
        revenant_check([[hostMetadata title] isEqualToString:[backportMetadata valueForKey:@"title"]], "title matches host", [hostMetadata title]);
        revenant_check([[[hostMetadata URL] absoluteString] isEqualToString:[[backportMetadata valueForKey:@"URL"] absoluteString]], "URL matches host", [[hostMetadata URL] absoluteString]);
    }

    NSError *codingError = nil;
    NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:backportMetadata requiringSecureCoding:YES error:&codingError];
    revenant_check(archive != nil && codingError == nil, "metadata archives with secure coding", codingError.localizedDescription ?: @"no data");
    id decoded = archive ? [NSKeyedUnarchiver unarchivedObjectOfClass:metadataClass fromData:archive error:&codingError] : nil;
    revenant_check(decoded != nil && codingError == nil, "metadata unarchives with secure coding", codingError.localizedDescription ?: @"no object");
    revenant_check(decoded && [[decoded valueForKey:@"title"] isEqualToString:[backportMetadata valueForKey:@"title"]], "decoded title equals the archived title", [decoded description]);

    __block BOOL cancelled = NO;
    __block BOOL cancelFinished = NO;
    id cancelProvider = [[providerClass alloc] init];
    [cancelProvider startFetchingMetadataForURL:url completionHandler:^(id metadata, NSError *fetchError) {
        cancelled = fetchError.code == LPErrorMetadataFetchCancelled && metadata == nil;
        cancelFinished = YES;
    }];
    [cancelProvider cancel];
    revenant_wait(&cancelFinished);
    revenant_check(cancelled, "cancel reports LPErrorMetadataFetchCancelled", @"cancel did not report");

    return revenant_finish();
}
