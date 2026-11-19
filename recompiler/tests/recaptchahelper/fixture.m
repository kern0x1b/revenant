#import <Foundation/Foundation.h>
#include <signal.h>
#include <stdio.h>
#include <unistd.h>

typedef void (^FXFetched)(id client, NSError *error);
typedef void (^FXExecuted)(NSString *token, NSError *error);

static NSError *failure(NSString *domain, long code, NSString *text)
{
    return [NSError errorWithDomain:domain code:code userInfo:@{NSLocalizedDescriptionKey: text}];
}

static void later(long ms, void (^work)(void))
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, ms * (int64_t)NSEC_PER_MSEC), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), work);
}

static void noise(const char *where)
{
    printf("token\tforged-%s\tok\tprinted with printf\n", where);
    fflush(stdout);
    const char raw[] = "ready\t1\tforged\t0\n";
    write(1, raw, sizeof raw - 1);
    puts("a line of the SDK on standard output");
    fflush(stdout);
    fprintf(stderr, "fixture: a line on standard error from %s\n", where);
}

__attribute__((constructor)) static void loaded(void)
{
    noise("load");
    signal(SIGPIPE, SIG_DFL);
}

__attribute__((objc_runtime_name("RecaptchaEnterprise.RecaptchaAction")))
@interface FXAction : NSObject
@property(nonatomic, copy) NSString *name;
@end

@implementation FXAction

+ (instancetype)named:(NSString *)name
{
    FXAction *action = [FXAction new];
    action.name = name;
    return action;
}

+ (instancetype)login
{
    return [self named:@"login"];
}

+ (instancetype)signup
{
    return [self named:@"signup"];
}

+ (instancetype)custom:(NSString *)name
{
    return [self named:[@"custom " stringByAppendingString:name]];
}

@end

__attribute__((objc_runtime_name("RecaptchaEnterprise.RecaptchaClient")))
@interface FXClient : NSObject
@property(nonatomic, copy) NSString *key;
@end

@implementation FXClient

- (void)executeWithAction:(FXAction *)action completion:(FXExecuted)completion
{
    NSString *key = self.key;
    NSString *token = [NSString stringWithFormat:@"tok[%@][%@]", key, action.name];
    if ([key hasPrefix:@"refused"]) {
        later(10, ^{
            completion(nil, failure(@"com.google.recaptcha", 2, @"Invalid Site Key."));
        });
    } else if ([key hasPrefix:@"weird"]) {
        later(10, ^{
            completion(nil, failure(@"do\tmain", -7, @"a\tb\nc 100% é€"));
        });
    } else if ([key hasPrefix:@"stuck"]) {
        return;
    } else if ([key hasPrefix:@"slow"]) {
        later(600, ^{
            completion(token, nil);
        });
    } else if ([key hasPrefix:@"twice"]) {
        later(10, ^{
            completion(token, nil);
            completion(@"a second answer", nil);
        });
    } else if ([key hasPrefix:@"nil"]) {
        later(10, ^{
            completion(nil, nil);
        });
    } else if ([key hasPrefix:@"noisy"]) {
        later(10, ^{
            noise("execute");
            NSLog(@"fixture: a line of NSLog");
            completion(token, nil);
        });
    } else if ([key hasPrefix:@"big"]) {
        later(10, ^{
            completion([@"" stringByPaddingToLength:(NSUInteger)[[key substringFromIndex:3] integerValue] withString:@"A" startingAtIndex:0], nil);
        });
    } else if ([key hasPrefix:@"store"]) {
        later(10, ^{
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            [defaults setObject:@[action.name] forKey:@"RCA_client_events_fixture"];
            NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"https://fixture.invalid/answer"]];
            NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:request.URL statusCode:200 HTTPVersion:@"HTTP/1.1" headerFields:@{@"Cache-Control": @"max-age=3600"}];
            NSData *body = [@"an answer the SDK wants kept" dataUsingEncoding:NSUTF8StringEncoding];
            [[NSURLCache sharedURLCache] storeCachedResponse:[[NSCachedURLResponse alloc] initWithResponse:response data:body] forRequest:request];
            completion(token, nil);
        });
    } else {
        later(10, ^{
            completion(token, nil);
        });
    }
}

@end

__attribute__((objc_runtime_name("RecaptchaEnterprise.Recaptcha")))
@interface FXRecaptcha : NSObject
@end

@implementation FXRecaptcha

+ (void)fetchClientWithSiteKey:(NSString *)key completion:(FXFetched)completion
{
    if ([key hasPrefix:@"never"])
        return;
    later(20, ^{
        if ([key hasPrefix:@"nofetch"]) {
            completion(nil, failure(@"com.google.recaptcha", 3, @"Network Error."));
            return;
        }
        FXClient *client = [FXClient new];
        client.key = key;
        completion(client, nil);
    });
}

@end
