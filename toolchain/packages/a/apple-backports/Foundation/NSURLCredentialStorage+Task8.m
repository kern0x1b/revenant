#import <Foundation/Foundation.h>

@implementation NSURLCredentialStorage (CharonTaskCredentials)

- (void)getCredentialsForProtectionSpace:(NSURLProtectionSpace *)space
                                    task:(NSURLSessionTask *)task
                        completionHandler:(void (^)(NSDictionary<NSString *, NSURLCredential *> *))completionHandler
{
    NSDictionary *found = [self credentialsForProtectionSpace:space];
    if (completionHandler)
        completionHandler(found);
}

- (void)getDefaultCredentialForProtectionSpace:(NSURLProtectionSpace *)space
                                          task:(NSURLSessionTask *)task
                              completionHandler:(void (^)(NSURLCredential *))completionHandler
{
    if (completionHandler)
        completionHandler([self defaultCredentialForProtectionSpace:space]);
}

- (void)setCredential:(NSURLCredential *)credential forProtectionSpace:(NSURLProtectionSpace *)space task:(NSURLSessionTask *)task
{
    [self setCredential:credential forProtectionSpace:space];
}

- (void)setDefaultCredential:(NSURLCredential *)credential forProtectionSpace:(NSURLProtectionSpace *)space task:(NSURLSessionTask *)task
{
    [self setDefaultCredential:credential forProtectionSpace:space];
}

- (void)removeCredential:(NSURLCredential *)credential forProtectionSpace:(NSURLProtectionSpace *)space task:(NSURLSessionTask *)task
{
    [self removeCredential:credential forProtectionSpace:space];
}

- (void)removeCredential:(NSURLCredential *)credential
      forProtectionSpace:(NSURLProtectionSpace *)space
                  options:(NSDictionary<NSString *, id> *)options
{
    if (options[NSURLCredentialStorageRemoveSynchronizableCredentials])
        return;
    [self removeCredential:credential forProtectionSpace:space];
}

- (void)removeCredential:(NSURLCredential *)credential
      forProtectionSpace:(NSURLProtectionSpace *)space
                  options:(NSDictionary<NSString *, id> *)options
                      task:(NSURLSessionTask *)task
{
    [self removeCredential:credential forProtectionSpace:space options:options];
}

@end
