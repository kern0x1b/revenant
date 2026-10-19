#import <Foundation/Foundation.h>

/* The credential storage's task-based half. Every one of them is the release's own method with the
   task's protection space: on a release whose credential storage has no notion of a task, a task
   argument is only ever nil or a task the application is holding, and the credential belongs to the
   space either way. The options dictionary of -removeCredential:forProtectionSpace:options: is where
   NSURLCredentialStorageRemoveSynchronizableCredentials lives, and 6.1.3 has no synchronizable
   credentials, so the option is read and has nothing to remove.

   The host's own Catalyst headers predate this half of the API, so these six are held by
   tests/backports/device/foundation15batch.m on the device rather than by a host differential. */

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
        return; /* nothing synchronizable is stored on a release that has no such credentials */
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
