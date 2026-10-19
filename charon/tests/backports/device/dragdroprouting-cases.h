#import <Foundation/Foundation.h>

// The order a view asks its own drop delegate in is asserted against Apple's, as a literal in
// dragdroprouting.m beside the reason from the header. Nothing here is read from the port: an
// expectation taken from the code under test cannot fail when the code is wrong, which is the hole
// this file previously had.
