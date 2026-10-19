// ARCollaborationData.m - the data a collaborating session shares, at 13.0.
//
// A collaborating session exchanges a map of the room and what it tracked in it, and this port runs no
// collaborating session (ARWorldTrackingConfiguration.collaborationEnabled is owed, ios13configurations.json),
// so no collaboration data is produced. The class is carried so the name resolves; its one member, priority, is
// the synthesised accessor of the SDK's property and answers the zero value. facts/ARKit/AbsentClasses.md.

#import <ARKit/ARKit.h>

NS_ASSUME_NONNULL_BEGIN

@implementation ARCollaborationData

@synthesize priority = _priority;

@end

NS_ASSUME_NONNULL_END
