#import "../Foundation/check.h"
#import <SceneKit/SceneKit.h>
#import "../../src/SceneKit/RevenantSCNActions.h"
#include <math.h>

static BOOL revenant_close(double value, double expected)
{
    return fabs(value - expected) <= 1e-4;
}

static RevenantSCNActionRun *revenant_run(SCNAction *action, void (^completion)(void))
{
    return [[RevenantSCNActionRun alloc] initWithAction:action key:nil completion:completion time:0];
}

static BOOL revenant_advance(RevenantSCNActionRun *run, SCNNode *node, NSTimeInterval dt)
{
    NSTimeInterval leftover = 0;
    return [run advanceBy:dt onNode:node leftover:&leftover];
}

static void revenant_expect_number(const char *name, double value, double expected)
{
    revenant_check(revenant_close(value, expected), name, [NSString stringWithFormat:@"%g is not %g", value, expected]);
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        revenant_read_arguments(argc, argv);

        SCNNode *node = [SCNNode node];
        RevenantSCNActionRun *run = revenant_run([SCNAction moveBy:SCNVector3Make(10, 0, 0) duration:2], nil);
        revenant_check(!revenant_advance(run, node, 1), "move by is running at half its duration", @"move by finished early");
        revenant_expect_number("move by is linear at half its duration", node.position.x, 5);
        revenant_check(revenant_advance(run, node, 1), "move by finishes at its duration", @"move by is still running");
        revenant_expect_number("move by ends at its delta", node.position.x, 10);

        node = [SCNNode node];
        SCNAction *fast = [SCNAction moveBy:SCNVector3Make(10, 0, 0) duration:2];
        fast.speed = 2;
        run = revenant_run(fast, nil);
        revenant_advance(run, node, 0.5);
        revenant_expect_number("speed two covers twice the distance in the same time", node.position.x, 5);

        node = [SCNNode node];
        SCNAction *eased = [SCNAction moveBy:SCNVector3Make(10, 0, 0) duration:2];
        eased.timingFunction = ^float(float time) {
            return time * time;
        };
        run = revenant_run(eased, nil);
        revenant_advance(run, node, 1);
        revenant_expect_number("timing function maps half the time to a quarter of the distance", node.position.x, 2.5);

        node = [SCNNode node];
        run = revenant_run([SCNAction sequence:@[[SCNAction moveBy:SCNVector3Make(10, 0, 0) duration:1],
                                                  [SCNAction waitForDuration:1],
                                                  [SCNAction moveBy:SCNVector3Make(0, 5, 0) duration:1]]], nil);
        revenant_advance(run, node, 1.5);
        revenant_expect_number("sequence holds the first move's end during a wait", node.position.x, 10);
        revenant_expect_number("sequence has not started the next move during a wait", node.position.y, 0);
        revenant_advance(run, node, 1);
        revenant_expect_number("sequence starts the next move after the wait", node.position.y, 2.5);

        node = [SCNNode node];
        node.opacity = 1;
        run = revenant_run([SCNAction group:@[[SCNAction moveBy:SCNVector3Make(10, 0, 0) duration:2],
                                               [SCNAction fadeOpacityTo:0 duration:1]]], nil);
        revenant_advance(run, node, 1);
        revenant_expect_number("group runs its moves together: position", node.position.x, 5);
        revenant_expect_number("group runs its moves together: opacity", node.opacity, 0);
        revenant_check(!revenant_advance(run, node, 0.5), "group waits for its longest action", @"group finished at one and a half seconds");
        revenant_check(revenant_advance(run, node, 0.5), "group finishes with its longest action", @"group is still running at two seconds");
        revenant_expect_number("group reaches the longest action's end", node.position.x, 10);

        node = [SCNNode node];
        run = revenant_run([SCNAction repeatAction:[SCNAction moveBy:SCNVector3Make(1, 0, 0) duration:1] count:3], nil);
        revenant_advance(run, node, 2.5);
        revenant_expect_number("repeat count three is halfway through its third repeat at two and a half seconds", node.position.x, 2.5);
        revenant_check(revenant_advance(run, node, 1), "repeat count three finishes at three repeats", @"repeat is still running");
        revenant_expect_number("repeat count three ends after three repeats", node.position.x, 3);

        node = [SCNNode node];
        run = revenant_run([SCNAction sequence:@[[SCNAction group:@[[SCNAction moveBy:SCNVector3Make(1, 0, 0) duration:1],
                                                                  [SCNAction waitForDuration:0.5]]],
                                                  [SCNAction moveBy:SCNVector3Make(0, 1, 0) duration:1]]], nil);
        revenant_advance(run, node, 2);
        revenant_expect_number("sequence passes the group's leftover time to the next action: x", node.position.x, 1);
        revenant_expect_number("sequence passes the group's leftover time to the next action: y", node.position.y, 1);

        __block BOOL called = NO;
        node = [SCNNode node];
        run = revenant_run([SCNAction sequence:@[[SCNAction moveBy:SCNVector3Make(1, 0, 0) duration:1],
                                                  [SCNAction runBlock:^(SCNNode *target) {
                                                      called = YES;
                                                  }]]], nil);
        revenant_advance(run, node, 0.5);
        revenant_check(!called, "run block waits for the move before it", @"run block ran early");
        revenant_advance(run, node, 0.5);
        revenant_check(called, "run block runs when its turn comes", @"run block did not run");

        node = [SCNNode node];
        node.scale = SCNVector3Make(1, 1, 1);
        run = revenant_run([SCNAction scaleTo:2 duration:1], nil);
        revenant_advance(run, node, 0.5);
        revenant_expect_number("scale to moves linearly to the target", node.scale.x, 1.5);
        revenant_expect_number("scale to scales every axis", node.scale.z, 1.5);

        node = [SCNNode node];
        node.opacity = 1;
        run = revenant_run([SCNAction fadeOpacityTo:0 duration:2], nil);
        revenant_advance(run, node, 1);
        revenant_expect_number("fade to moves linearly to the target", node.opacity, 0.5);

        node = [SCNNode node];
        run = revenant_run([SCNAction rotateByX:0 y:0 z:M_PI / 2 duration:1], nil);
        revenant_advance(run, node, 1);
        revenant_expect_number("rotate by adds the angle to the Euler angles", node.eulerAngles.z, M_PI / 2);

        node = [SCNNode node];
        run = revenant_run([SCNAction hide], nil);
        revenant_advance(run, node, 0);
        revenant_check(node.hidden, "hide hides the node at once", @"node is visible");

        SCNNode *parent = [SCNNode node];
        node = [SCNNode node];
        [parent addChildNode:node];
        run = revenant_run([SCNAction removeFromParentNode], nil);
        revenant_advance(run, node, 0);
        revenant_check(node.parentNode == nil, "remove from parent detaches the node", @"node is still attached");

        __block NSTimeInterval seen = -1;
        node = [SCNNode node];
        run = revenant_run([SCNAction customActionWithDuration:1 actionBlock:^(SCNNode *target, CGFloat elapsed) {
            seen = elapsed;
        }], nil);
        revenant_advance(run, node, 0.5);
        revenant_expect_number("custom action sees the elapsed time", seen, 0.5);
        revenant_advance(run, node, 0.5);
        revenant_expect_number("custom action sees the full duration at its end", seen, 1);

        revenant_expect_number("sequence duration is the sum of its actions", [SCNAction sequence:@[[SCNAction waitForDuration:1], [SCNAction waitForDuration:2]]].duration, 3);
        revenant_expect_number("group duration is the longest of its actions", [SCNAction group:@[[SCNAction waitForDuration:1], [SCNAction waitForDuration:2]]].duration, 2);
        revenant_expect_number("repeat duration is the count times the action", [SCNAction repeatAction:[SCNAction waitForDuration:1] count:3].duration, 3);
        revenant_check(isinf([SCNAction repeatActionForever:[SCNAction waitForDuration:1]].duration), "repeat forever has an infinite duration", @"duration is finite");

        SCNAction *copy = [[SCNAction moveBy:SCNVector3Make(1, 2, 3) duration:4] copy];
        revenant_expect_number("copy keeps the duration", copy.duration, 4);
        revenant_check(copy.revenantKind == RevenantSCNActionKindMoveBy, "copy keeps the kind", @"copy changed the kind");

        revenant_check(revenant_negative ? NO : YES, "negative control", @"the negative control is inverted");
    }
    return revenant_finish();
}
