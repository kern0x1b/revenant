// The stand-in for the framework, for a host check: the port's own sources import this and the check
// above declares every class and protocol it needs. Empty on purpose - this Mac's real MediaPlayer has
// MPContentItem and friends, and finding those here would make the check measure the host instead of
// the port.
#import <Foundation/Foundation.h>
