#import <Foundation/Foundation.h>
#import <objc/runtime.h>

int main(void) {
    @autoreleasepool {
        Protocol *taskDelegate = @protocol(NSURLSessionTaskDelegate);
        Protocol *dataDelegate = @protocol(NSURLSessionDataDelegate);
        Protocol *downloadDelegate = @protocol(NSURLSessionDownloadDelegate);
        
        assert(taskDelegate != NULL);
        assert(dataDelegate != NULL);
        assert(downloadDelegate != NULL);
        
        assert(protocol_conformsToProtocol(dataDelegate, taskDelegate));
        assert(protocol_conformsToProtocol(downloadDelegate, taskDelegate));
        
        return 0;
    }
}