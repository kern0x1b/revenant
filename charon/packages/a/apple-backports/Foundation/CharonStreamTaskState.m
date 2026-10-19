#import "CharonStreamTaskState.h"

/* The state class of one stream task, in an object of its own so that the task's object holds one
   release group and this one holds none. Named for the task, private to the port, and not an API. */
@implementation NSURLSessionStreamTaskState

@synthesize session = _session;
@synthesize hostName = _hostName;
@synthesize hostPort = _hostPort;
@synthesize input = _input;
@synthesize output = _output;
@synthesize readOpen = _readOpen;
@synthesize writeOpen = _writeOpen;
@synthesize secure = _secure;
@synthesize captured = _captured;
@synthesize finished = _finished;
@synthesize readClosedReported = _readClosedReported;
@synthesize openedAt = _openedAt;
@synthesize started = _started;
@synthesize socketNamesRead = _socketNamesRead;
@synthesize localAddress = _localAddress;
@synthesize localPort = _localPort;
@synthesize remoteAddress = _remoteAddress;
@synthesize remotePort = _remotePort;
@synthesize tlsProtocolVersion = _tlsProtocolVersion;
@synthesize tlsCipherSuite = _tlsCipherSuite;

@end
