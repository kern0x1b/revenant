#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import <arpa/inet.h>
#import <netinet/in.h>
#import <pthread.h>
#import <sys/socket.h>
#import <unistd.h>
#import <zlib.h>
#import "RevenantDocument.h"
#import "RevenantScriptCodec.h"

static NSString *const Early = @"window.early = 'set-by-start';";

static NSString *const Page = @"<!DOCTYPE html><html><head><title>page</title><script>var seen = window.early;</script></head><body>café</body></html>";

static NSString *const StartPage = @"<!DOCTYPE html><html><head><title>start</title><script>var seen = window.early;</script></head><body>café</body></html>";

static NSData *UTF8(NSString *text)
{
    return [text dataUsingEncoding:NSUTF8StringEncoding];
}

static NSData *Latin1(NSString *text)
{
    return [text dataUsingEncoding:NSISOLatin1StringEncoding];
}

static NSData *Gzip(NSData *input)
{
    z_stream stream;
    memset(&stream, 0, sizeof stream);
    deflateInit2(&stream, Z_DEFAULT_COMPRESSION, Z_DEFLATED, 15 + 16, 8, Z_DEFAULT_STRATEGY);
    NSMutableData *output = [NSMutableData dataWithLength:(NSUInteger)deflateBound(&stream, input.length) + 64];
    stream.next_in = (Bytef *)input.bytes;
    stream.avail_in = (uInt)input.length;
    stream.next_out = output.mutableBytes;
    stream.avail_out = (uInt)output.length;
    deflate(&stream, Z_FINISH);
    output.length = stream.total_out;
    deflateEnd(&stream);
    return output;
}

static NSData *Message(NSString *status, NSString *headers, NSData *body)
{
    NSString *head = [NSString stringWithFormat:@"HTTP/1.1 %@\r\n%@Content-Length: %lu\r\nConnection: close\r\n\r\n", status, headers, (unsigned long)body.length];
    NSMutableData *message = [[head dataUsingEncoding:NSASCIIStringEncoding] mutableCopy];
    [message appendData:body];
    return message;
}

static NSString *HeaderNamed(NSString *head, NSString *name)
{
    for (NSString *line in [head componentsSeparatedByString:@"\r\n"]) {
        NSString *prefix = [name stringByAppendingString:@":"];
        if ([line.lowercaseString hasPrefix:prefix.lowercaseString])
            return [[line substringFromIndex:prefix.length] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    }
    return @"";
}

static NSData *Reply(NSString *method, NSString *path, NSString *head, NSData *requestBody)
{
    if ([path hasPrefix:@"/echo"]) {
        NSString *probe = HeaderNamed(head, @"X-Probe");
        NSString *body = [[NSString alloc] initWithData:requestBody encoding:NSASCIIStringEncoding] ?: @"";
        NSString *html = [NSString stringWithFormat:@"<!DOCTYPE html><html><head></head><body><script>var seen = window.early + '|%@|%@|%@';</script></body></html>", method, probe, body];
        return Message(@"200 OK", @"Content-Type: text/html; charset=utf-8\r\n", UTF8(html));
    }
    if ([path isEqualToString:@"/start"] || [path isEqualToString:@"/deny"])
        return Message(@"200 OK", @"Content-Type: text/html; charset=utf-8\r\n", UTF8(StartPage));
    if ([path isEqualToString:@"/redirect/1"])
        return Message(@"302 Found", @"Location: /redirect/2\r\n", [NSData data]);
    if ([path isEqualToString:@"/redirect/2"])
        return Message(@"301 Moved Permanently", @"Location: /start\r\n", [NSData data]);
    if ([path isEqualToString:@"/gzip"])
        return Message(@"200 OK", @"Content-Type: text/html; charset=utf-8\r\nContent-Encoding: gzip\r\n", Gzip(UTF8(StartPage)));
    if ([path isEqualToString:@"/latin1"])
        return Message(@"200 OK", @"Content-Type: text/html; charset=iso-8859-1\r\n", Latin1(@"<!DOCTYPE html><html><head></head><body>café</body></html>"));
    if ([path isEqualToString:@"/meta"])
        return Message(@"200 OK", @"Content-Type: text/html\r\n", Latin1(@"<!DOCTYPE html><html><head><meta charset=\"iso-8859-1\"></head><body>café</body></html>"));
    if ([path isEqualToString:@"/json"])
        return Message(@"200 OK", @"Content-Type: application/json\r\n", UTF8(@"{\"head\":\"<head>\"}"));
    if ([path isEqualToString:@"/missing"])
        return Message(@"404 Not Found", @"Content-Type: text/html\r\n", UTF8(@"<html><head></head>nope</html>"));
    if ([path isEqualToString:@"/csp"])
        return Message(@"200 OK", @"Content-Type: text/html; charset=utf-8\r\nContent-Security-Policy: default-src 'self'; script-src 'self'\r\n", UTF8(StartPage));
    if ([path isEqualToString:@"/csp-meta"])
        return Message(@"200 OK", @"Content-Type: text/html; charset=utf-8\r\n", UTF8(@"<!DOCTYPE html><html><head><meta http-equiv=\"Content-Security-Policy\" content=\"script-src 'self'\"><title>x</title></head><body></body></html>"));
    return Message(@"404 Not Found", @"Content-Type: text/plain\r\n", UTF8(@"not found"));
}

static void Serve(int listener)
{
    NSData *separator = [NSData dataWithBytes:"\r\n\r\n" length:4];
    for (;;) {
        @autoreleasepool {
            int client = accept(listener, NULL, NULL);
            if (client < 0)
                continue;
            NSMutableData *request = [NSMutableData data];
            char buffer[2048];
            ssize_t count = 1;
            while (count > 0 && [request rangeOfData:separator options:0 range:NSMakeRange(0, request.length)].location == NSNotFound) {
                count = read(client, buffer, sizeof buffer);
                if (count > 0)
                    [request appendBytes:buffer length:(NSUInteger)count];
            }
            NSRange split = [request rangeOfData:separator options:0 range:NSMakeRange(0, request.length)];
            NSUInteger headLength = split.location == NSNotFound ? request.length : split.location;
            NSString *head = [[NSString alloc] initWithData:[request subdataWithRange:NSMakeRange(0, headLength)] encoding:NSASCIIStringEncoding] ?: @"";
            NSUInteger bodyStart = split.location == NSNotFound ? request.length : NSMaxRange(split);
            NSUInteger expected = (NSUInteger)[HeaderNamed(head, @"Content-Length") integerValue];
            while (count > 0 && request.length - bodyStart < expected) {
                count = read(client, buffer, sizeof buffer);
                if (count > 0)
                    [request appendBytes:buffer length:(NSUInteger)count];
            }
            NSUInteger available = MIN(expected, request.length - bodyStart);
            NSData *requestBody = [request subdataWithRange:NSMakeRange(bodyStart, available)];
            NSArray *words = [[head componentsSeparatedByString:@"\r\n"].firstObject componentsSeparatedByString:@" "];
            NSString *method = words.count > 0 ? words[0] : @"GET";
            NSString *path = words.count > 1 ? words[1] : @"/";
            NSData *reply = Reply(method, path, head, requestBody);
            const char *bytes = reply.bytes;
            size_t remaining = reply.length;
            while (remaining > 0) {
                ssize_t sent = write(client, bytes, remaining);
                if (sent <= 0)
                    break;
                bytes += sent;
                remaining -= (size_t)sent;
            }
            close(client);
        }
    }
}

static int listenerDescriptor;

static void *ServerThread(void *argument)
{
    Serve(listenerDescriptor);
    return NULL;
}

static int StartServer(void)
{
    listenerDescriptor = socket(AF_INET, SOCK_STREAM, 0);
    struct sockaddr_in address;
    memset(&address, 0, sizeof address);
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    address.sin_port = 0;
    bind(listenerDescriptor, (struct sockaddr *)&address, sizeof address);
    socklen_t length = sizeof address;
    getsockname(listenerDescriptor, (struct sockaddr *)&address, &length);
    listen(listenerDescriptor, 8);
    pthread_t thread;
    pthread_create(&thread, NULL, ServerThread, NULL);
    pthread_detach(thread);
    return ntohs(address.sin_port);
}

@interface Source : NSObject <RevenantDocumentSource>
@property (nonatomic) BOOL injected;
@property (nonatomic) NSUInteger injections;
@end

@implementation Source

- (NSArray<NSString *> *)revenant_documentStartScripts
{
#ifdef DOCUMENT_NEGATIVE_CONTROL
    return @[];
#else
    return @[Early];
#endif
}

- (void)revenant_documentDidInject
{
    self.injected = YES;
    self.injections++;
}

- (void)revenant_decideResponse:(NSURLResponse *)response completion:(void (^)(NSInteger))completion
{
    completion([response.URL.path isEqualToString:@"/deny"] ? 0 : 1);
}

- (void)revenant_downloadResponse:(NSURLResponse *)response request:(NSURLRequest *)request
{
}

@end

@interface Loader : NSObject <NSURLConnectionDataDelegate>
@property (nonatomic, strong) NSHTTPURLResponse *response;
@property (nonatomic, strong) NSMutableData *data;
@property (nonatomic, strong) NSError *error;
@property (nonatomic) BOOL finished;
@end

@implementation Loader

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    self.response = (NSHTTPURLResponse *)response;
    self.data = [NSMutableData data];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [self.data appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    self.finished = YES;
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    self.error = error;
    self.finished = YES;
}

@end

static Loader *FetchRequest(NSURLRequest *request)
{
    Loader *loader = [[Loader alloc] init];
    NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:loader startImmediately:YES];
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:10];
    while (!loader.finished && [deadline timeIntervalSinceNow] > 0)
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    [connection cancel];
    return loader;
}

static Loader *Fetch(NSString *URLString, NSString *token)
{
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:URLString]];
    RevenantDocumentTagRequest(request, token);
    return FetchRequest(request);
}

static NSString *Flag(NSString *label, BOOL value)
{
    return [NSString stringWithFormat:@"%@: %d", label, value];
}

static NSString *Count(NSString *label, NSUInteger value)
{
    return [NSString stringWithFormat:@"%@: %lu", label, (unsigned long)value];
}

static BOOL HasHeader(NSHTTPURLResponse *response, NSString *name)
{
    for (NSString *key in response.allHeaderFields) {
        if ([key.lowercaseString isEqualToString:name.lowercaseString])
            return YES;
    }
    return NO;
}

static NSString *PageScriptSawEncoded(NSData *body, NSStringEncoding encoding)
{
    NSString *html = [[NSString alloc] initWithData:body encoding:encoding] ?: @"";
    JSContext *context = [[JSContext alloc] init];
    [context evaluateScript:@"var window = this;"];
    NSRegularExpression *scripts = [NSRegularExpression regularExpressionWithPattern:@"<script>(.*?)</script>" options:NSRegularExpressionDotMatchesLineSeparators error:NULL];
    for (NSTextCheckingResult *match in [scripts matchesInString:html options:0 range:NSMakeRange(0, html.length)])
        [context evaluateScript:[html substringWithRange:[match rangeAtIndex:1]]];
    JSValue *seen = context[@"seen"];
    return seen.isUndefined ? @"undefined" : [seen toString];
}

static NSString *PageScriptSaw(NSData *body)
{
    return PageScriptSawEncoded(body, NSUTF8StringEncoding);
}

static NSString *IndependentHash(NSString *script)
{
    NSData *bytes = UTF8(script);
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(bytes.bytes, (CC_LONG)bytes.length, digest);
    return [[NSData dataWithBytes:digest length:sizeof digest] base64EncodedStringWithOptions:0];
}

static BOOL DecodesAsLatin1(NSData *body, NSString *text)
{
    NSString *decoded = [[NSString alloc] initWithData:body encoding:NSISOLatin1StringEncoding];
    return [decoded containsString:text];
}

static NSString *const ShimStubs =
    @"var window=this; window.top=window;"
    @"var document={documentElement:{appendChild:function(){}},getElementsByTagName:function(){return [];},"
    @"createElement:function(){return {style:{}};}};"
    @"var setTimeout=function(){};";

int main(int argc, const char *argv[])
{
    @autoreleasepool {
        NSString *base = [NSString stringWithFormat:@"http://127.0.0.1:%d", StartServer()];
        Source *source = [[Source alloc] init];
        NSString *token = RevenantDocumentRegister(source);
        NSMutableArray<NSString *> *lines = [NSMutableArray array];
        NSString *earlyHash = IndependentHash(Early);

        Loader *start = Fetch([base stringByAppendingString:@"/start"], token);
        [lines addObject:Flag(@"start injected", source.injected)];
        [lines addObject:[NSString stringWithFormat:@"start page script saw: %@", PageScriptSaw(start.data)]];

        source.injected = NO;
        Loader *redirect = Fetch([base stringByAppendingString:@"/redirect/1"], token);
        [lines addObject:Flag(@"redirect final is start", [redirect.response.URL.path isEqualToString:@"/start"])];
        [lines addObject:Flag(@"redirect injected", source.injected)];
        [lines addObject:[NSString stringWithFormat:@"redirect page script saw: %@", PageScriptSaw(redirect.data)]];

        source.injected = NO;
        NSURL *linkURL = [NSURL URLWithString:[base stringByAppendingString:@"/echo?link=1"]];
        NSMutableURLRequest *link = [NSMutableURLRequest requestWithURL:linkURL];
        [link setValue:@"probe-42" forHTTPHeaderField:@"X-Probe"];
        NSURLRequest *taggedLink = RevenantDocumentTaggedCopy(link, token);
        [lines addObject:Flag(@"link tagged copy keeps the original", !RevenantDocumentIsTagged(link) && RevenantDocumentIsTagged(taggedLink))];
        Loader *linked = FetchRequest(taggedLink);
        [lines addObject:Flag(@"link injected", source.injected)];
        [lines addObject:[NSString stringWithFormat:@"link page script saw: %@", PageScriptSaw(linked.data)]];

        source.injected = NO;
        NSMutableURLRequest *form = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[base stringByAppendingString:@"/echo"]]];
        form.HTTPMethod = @"POST";
        form.HTTPBody = UTF8(@"field=value");
        [form setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
        [form setValue:@"probe-42" forHTTPHeaderField:@"X-Probe"];
        Loader *posted = FetchRequest(RevenantDocumentTaggedCopy(form, token));
        [lines addObject:Flag(@"form injected", source.injected)];
        [lines addObject:[NSString stringWithFormat:@"form page script saw: %@", PageScriptSaw(posted.data)]];

        NSURL *historyURL = [NSURL URLWithString:[base stringByAppendingString:@"/echo?history=1"]];
        NSUInteger before = source.injections;
        RevenantDocumentExpect(token, historyURL);
        Loader *history = FetchRequest([NSURLRequest requestWithURL:historyURL]);
        [lines addObject:Count(@"history network starts", source.injections - before)];
        [lines addObject:[NSString stringWithFormat:@"history network page script saw: %@", PageScriptSaw(history.data)]];

        before = source.injections;
        FetchRequest([NSURLRequest requestWithURL:historyURL]);
        [lines addObject:Count(@"history repeat starts", source.injections - before)];

        NSURL *forgottenURL = [NSURL URLWithString:[base stringByAppendingString:@"/echo?forgotten=1"]];
        before = source.injections;
        RevenantDocumentExpect(token, forgottenURL);
        RevenantDocumentForget(token);
        FetchRequest([NSURLRequest requestWithURL:forgottenURL]);
        [lines addObject:Count(@"forgotten expectation starts", source.injections - before)];

        NSURL *startURL = [NSURL URLWithString:[base stringByAppendingString:@"/start"]];
        Fetch(startURL.absoluteString, token);
        before = source.injections;
        RevenantDocumentExpect(token, startURL);
        FetchRequest([NSURLRequest requestWithURL:startURL]);
        [lines addObject:Count(@"reload starts", source.injections - before)];

        source.injected = NO;
        Loader *gzip = Fetch([base stringByAppendingString:@"/gzip"], token);
        [lines addObject:Flag(@"gzip injected", source.injected)];
        [lines addObject:Flag(@"gzip header removed", !HasHeader(gzip.response, @"Content-Encoding"))];
        [lines addObject:Flag(@"gzip length matches", [gzip.response.allHeaderFields[@"Content-Length"] integerValue] == (NSInteger)gzip.data.length)];
        [lines addObject:[NSString stringWithFormat:@"gzip page script saw: %@", PageScriptSaw(gzip.data)]];

        source.injected = NO;
        Loader *latin = Fetch([base stringByAppendingString:@"/latin1"], token);
        [lines addObject:Flag(@"latin1 injected", source.injected)];
        [lines addObject:Flag(@"latin1 charset kept", [latin.response.textEncodingName.lowercaseString isEqualToString:@"iso-8859-1"])];
        [lines addObject:Flag(@"latin1 decodes as iso-8859-1", DecodesAsLatin1(latin.data, @"café"))];
        [lines addObject:Flag(@"latin1 start script present", DecodesAsLatin1(latin.data, Early))];

        source.injected = NO;
        Loader *meta = Fetch([base stringByAppendingString:@"/meta"], token);
        [lines addObject:Flag(@"meta charset injected", source.injected)];
        [lines addObject:Flag(@"meta charset decodes as iso-8859-1", DecodesAsLatin1(meta.data, @"café"))];

        source.injected = NO;
        Loader *json = Fetch([base stringByAppendingString:@"/json"], token);
        [lines addObject:Flag(@"json injected", source.injected)];
        [lines addObject:Flag(@"json bytes identical", [json.data isEqualToData:UTF8(@"{\"head\":\"<head>\"}")])];

        source.injected = NO;
        Loader *missing = Fetch([base stringByAppendingString:@"/missing"], token);
        [lines addObject:Flag(@"missing injected", source.injected)];
        [lines addObject:Flag(@"missing bytes identical", [missing.data isEqualToData:UTF8(@"<html><head></head>nope</html>")])];

        source.injected = NO;
        Loader *csp = Fetch([base stringByAppendingString:@"/csp"], token);
        NSString *policy = csp.response.allHeaderFields[@"Content-Security-Policy"] ?: @"";
        [lines addObject:Flag(@"csp injected", source.injected)];
        [lines addObject:Flag(@"csp header hash", [policy containsString:[NSString stringWithFormat:@"'sha256-%@'", earlyHash]])];
        [lines addObject:[NSString stringWithFormat:@"csp page script saw: %@", PageScriptSaw(csp.data)]];

        source.injected = NO;
        Loader *cspMeta = Fetch([base stringByAppendingString:@"/csp-meta"], token);
        NSString *metaBody = [[NSString alloc] initWithData:cspMeta.data encoding:NSUTF8StringEncoding] ?: @"";
        [lines addObject:Flag(@"csp meta hash", [metaBody containsString:[NSString stringWithFormat:@"'sha256-%@'", earlyHash]])];

        source.injected = NO;
        Loader *denied = Fetch([base stringByAppendingString:@"/deny"], token);
        [lines addObject:Flag(@"response denied", denied.error.code == NSURLErrorCancelled && denied.response == nil && denied.data == nil)];
        [lines addObject:Flag(@"response denied injected", source.injected)];

        NSString *htmlString = RevenantDocumentInsert(Page, @[Early]);
        [lines addObject:[NSString stringWithFormat:@"loadHTMLString page saw: %@", PageScriptSawEncoded(UTF8(htmlString), NSUTF8StringEncoding)]];
        NSData *data = RevenantDocumentRewrite(Latin1(Page), nil, @"iso-8859-1", @[Early]);
        [lines addObject:[NSString stringWithFormat:@"loadData page saw: %@", data ? PageScriptSawEncoded(data, NSISOLatin1StringEncoding) : @"nil"]];
        NSString *directory = [NSTemporaryDirectory() stringByAppendingPathComponent:@"revenant-document-start-test"];
        [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL];
        NSString *file = [directory stringByAppendingPathComponent:@"page.html"];
        [UTF8(Page) writeToFile:file atomically:NO];
        NSData *fileDocument = RevenantDocumentRewrite([NSData dataWithContentsOfFile:file], nil, nil, @[Early]);
        [lines addObject:[NSString stringWithFormat:@"loadFileURL page saw: %@", fileDocument ? PageScriptSaw(fileDocument) : @"nil"]];

        NSString *shimmed = nil;
        JSContext *context = [[JSContext alloc] init];
        [context evaluateScript:ShimStubs];
        shimmed = [[context evaluateScript:RevenantDocumentStartedScript(token)] toString];
        [lines addObject:Flag(@"started marker absent before the shim", [shimmed isEqualToString:@"false"])];
        [context evaluateScript:[NSString stringWithFormat:RevenantShim, RevenantEncoder, @"[]", token]];
        shimmed = [[context evaluateScript:RevenantDocumentStartedScript(token)] toString];
        [lines addObject:Flag(@"started marker set by the shim", [shimmed isEqualToString:@"true"])];

        NSString *noHead = RevenantDocumentInsert(@"<p>x</p>", @[@"a=1;"]);
        [lines addObject:Flag(@"document start without head", [noHead hasPrefix:@"<script>a=1;</script><p>"])];
        NSString *doctype = RevenantDocumentInsert(@"<!DOCTYPE html><p>x</p>", @[@"a=1;"]);
        [lines addObject:Flag(@"after doctype", [doctype hasPrefix:@"<!DOCTYPE html><script>a=1;</script><p>"])];
        NSString *escaped = RevenantDocumentInsert(@"<head></head>", @[@"var s='é';"]);
        [lines addObject:Flag(@"non-ascii escaped", [escaped containsString:@"\\u00e9"] && ![escaped containsString:@"é"])];
        NSString *closing = RevenantDocumentInsert(@"<head></head>", @[@"var s='</script>';"]);
        [lines addObject:Flag(@"script end tag escaped", [closing componentsSeparatedByString:@"</script>"].count == 2)];

        for (NSString *line in lines)
            printf("%s\n", line.UTF8String);
    }
    return 0;
}
