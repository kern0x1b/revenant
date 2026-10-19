#import "CharonMetricKit.h"

// The error domain of the launch-measurement errors, which arrived in iOS 16.0: the one API of the
// framework this object carries. The iOS 13.4 manager in MXMetricManager.m answers the same string
// under its own name, so the two objects share no symbol.

NSString *const MXErrorDomain = @"MXErrorDomain";
