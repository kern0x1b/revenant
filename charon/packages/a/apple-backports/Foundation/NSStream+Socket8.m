#import <Foundation/Foundation.h>
#import <CoreFoundation/CFStream.h>
#include <string.h>

/* A pair of streams over a TCP connection, made the way iOS 8's own header says: the CFStream pair is
   created for the host and port and the two halves are bridged into the two stream classes. Nothing
   is reimplemented here -- the release's own CoreFoundation does the resolution, the socket and the
   buffering.

   Measured on this release, with tools/corpus/cache-value.lua over the 6.1.3 armv7 cache:
   `CFStreamCreatePairWithSocketToHost`, `CFStreamCreatePairWithSocket` and `CFStreamCreateBoundPair` are
   exported by /System/Library/Frameworks/CoreFoundation.framework/CoreFoundation, as are
   CFReadStreamSetProperty, CFWriteStreamSetProperty and kCFStreamPropertySocketNativeHandle. The
   declaration is in the SDK's own CFStream.h, so this is public API and not a private call.

   The bound pair is guarded to macOS in the 26.2 header and the iOS surface still names the method,
   so it is carried here: the release exports the function, and a pair bound to a port is what the
   method promises. */

@implementation NSStream (CharonSocket)

+ (void)getStreamsToHostWithName:(NSString *)hostname
                             port:(NSInteger)port
                     inputStream:(NSInputStream **)inputStream
                    outputStream:(NSOutputStream **)outputStream
{
    CFReadStreamRef read = NULL;
    CFWriteStreamRef write = NULL;
    CFStreamCreatePairWithSocketToHost(NULL, (__bridge CFStringRef)hostname, (UInt32)port, &read, &write);
    /* The pair's halves are the system's own stream objects, which is why the bridging is free. */
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
