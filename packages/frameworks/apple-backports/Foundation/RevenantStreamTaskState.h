#import <Foundation/Foundation.h>

@interface NSURLSessionStreamTaskState : NSObject
@property NSURLSession *session;
@property NSString *hostName;
@property NSInteger hostPort;
@property NSInputStream *input;
@property NSOutputStream *output;
@property BOOL readOpen;
@property BOOL writeOpen;
@property BOOL secure;
@property BOOL captured;
@property BOOL finished;
@property BOOL readClosedReported;
@property NSDate *openedAt;
@property BOOL started;
@property BOOL socketNamesRead;
@property NSString *localAddress;
@property NSNumber *localPort;
@property NSString *remoteAddress;
@property NSNumber *remotePort;
@property NSNumber *tlsProtocolVersion;
@property NSNumber *tlsCipherSuite;
@end
