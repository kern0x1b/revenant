#import <Foundation/Foundation.h>
#import <CoreFoundation/CFStream.h>
#include <string.h>

@implementation NSStream (CharonSocket)

+ (void)getStreamsToHostWithName:(NSString *)hostname
                             port:(NSInteger)port
                     inputStream:(NSInputStream **)inputStream
                    outputStream:(NSOutputStream **)outputStream
{
    CFReadStreamRef read = NULL;
    CFWriteStreamRef write = NULL;
    CFStreamCreatePairWithSocketToHost(NULL, (__bridge CFStringRef)hostname, (UInt32)port, &read, &write);
    if (inputStream)
        *inputStream = (__bridge NSInputStream *)read;
    else if (read)
        CFRelease(read);
    if (outputStream)
        *outputStream = (__bridge NSOutputStream *)write;
    else if (write)
        CFRelease(write);
}

+ (void)getBoundStreamsWithBufferSize:(NSUInteger)bufferSize
                         inputStream:(NSInputStream **)inputStream
                        outputStream:(NSOutputStream **)outputStream
{
    CFReadStreamRef read = NULL;
    CFWriteStreamRef write = NULL;
    CFStreamCreateBoundPair(NULL, &read, &write, (CFIndex)bufferSize);
    if (inputStream)
        *inputStream = (__bridge NSInputStream *)read;
    else if (read)
        CFRelease(read);
    if (outputStream)
        *outputStream = (__bridge NSOutputStream *)write;
    else if (write)
        CFRelease(write);
}

@end
