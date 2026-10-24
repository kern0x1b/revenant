#import "../Foundation/check.h"
#import <SceneKit/SceneKit.h>
#import "../../src/SceneKit/RevenantSCNActions.h"
#import "../../src/SceneKit/RevenantSCNAudio.h"
#import "wave_file.h"
#import <AVFoundation/AVFoundation.h>

static NSMutableArray<SCNAudioPlayer *> *revenant_added_players;

@interface RevenantFakeNode : SCNNode
@end

@implementation RevenantFakeNode

- (void)addAudioPlayer:(SCNAudioPlayer *)player
{
    [revenant_added_players addObject:player];
    [player revenantStartOnNode:nil];
}

@end
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

static void revenant_expect_near(const char *name, double value, double expected, double tolerance)
{
    revenant_check(fabs(value - expected) <= tolerance, name, [NSString stringWithFormat:@"%g is not %g", value, expected]);
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

        node = [SCNNode node];
        node.scale = SCNVector3Make(1, 1, 1);
        run = revenant_run([SCNAction scaleBy:2 duration:1], nil);
        revenant_advance(run, node, 0.5);
        revenant_expect_number("scale by adds the amount of change to the scale", node.scale.x, 2);
        revenant_advance(run, node, 0.5);
        revenant_expect_number("scale by ends at the start plus the amount", node.scale.x, 3);

        node = [SCNNode node];
        node.opacity = 0.5;
        run = revenant_run([SCNAction fadeOpacityBy:0.25 duration:1], nil);
        revenant_advance(run, node, 1);
        revenant_expect_number("fade opacity by adds the amount of change", node.opacity, 0.75);

        node = [SCNNode node];
        run = revenant_run([SCNAction moveBy:SCNVector3Make(10, 0, 0) duration:2].reversedAction, nil);
        revenant_advance(run, node, 2);
        revenant_expect_number("reversed move by moves the same distance the other way", node.position.x, -10);

        node = [SCNNode node];
        node.eulerAngles = SCNVector3Make(0, 0, 0);
        run = revenant_run([SCNAction rotateByX:0 y:0 z:M_PI / 2 duration:1].reversedAction, nil);
        revenant_advance(run, node, 1);
        revenant_expect_number("reversed rotate by turns the other way", node.eulerAngles.z, -M_PI / 2);

        node = [SCNNode node];
        node.scale = SCNVector3Make(5, 5, 5);
        run = revenant_run([SCNAction scaleBy:2 duration:1].reversedAction, nil);
        revenant_advance(run, node, 1);
        revenant_expect_number("reversed scale by undoes the change", node.scale.x, 3);

        node = [SCNNode node];
        node.opacity = 0.2;
        run = revenant_run([SCNAction fadeInWithDuration:1].reversedAction, nil);
        revenant_advance(run, node, 1);
        revenant_expect_number("reversed fade in fades out", node.opacity, 0);

        node = [SCNNode node];
        node.opacity = 0.5;
        run = revenant_run([SCNAction fadeOutWithDuration:1].reversedAction, nil);
        revenant_advance(run, node, 1);
        revenant_expect_number("reversed fade out fades in", node.opacity, 1);

        node = [SCNNode node];
        node.hidden = YES;
        run = revenant_run([SCNAction hide].reversedAction, nil);
        revenant_advance(run, node, 0);
        revenant_check(!node.hidden, "reversed hide unhides", @"node is still hidden");

        node = [SCNNode node];
        run = revenant_run([SCNAction sequence:@[[SCNAction moveBy:SCNVector3Make(10, 0, 0) duration:1],
                                                  [SCNAction moveBy:SCNVector3Make(0, 5, 0) duration:1]]].reversedAction, nil);
        revenant_advance(run, node, 1);
        revenant_expect_number("reversed sequence runs the last action first: y", node.position.y, -5);
        revenant_expect_number("reversed sequence runs the last action first: x", node.position.x, 0);
        revenant_advance(run, node, 1);
        revenant_expect_number("reversed sequence reverses each action: x", node.position.x, -10);

        node = [SCNNode node];
        node.opacity = 1;
        run = revenant_run([SCNAction group:@[[SCNAction moveBy:SCNVector3Make(10, 0, 0) duration:2],
                                               [SCNAction fadeInWithDuration:1]]].reversedAction, nil);
        revenant_advance(run, node, 2);
        revenant_expect_number("reversed group reverses each member: position", node.position.x, -10);
        revenant_expect_number("reversed group reverses each member: opacity", node.opacity, 0);

        node = [SCNNode node];
        run = revenant_run([SCNAction repeatAction:[SCNAction moveBy:SCNVector3Make(1, 0, 0) duration:1] count:3].reversedAction, nil);
        revenant_advance(run, node, 3);
        revenant_expect_number("reversed repeat repeats the reversed action", node.position.x, -3);

        node = [SCNNode node];
        SCNAction *toTarget = [SCNAction moveTo:SCNVector3Make(5, 5, 5) duration:2];
        SCNAction *undone = toTarget.reversedAction;
        revenant_expect_number("reversed move to keeps its duration", undone.duration, 2);
        run = revenant_run(undone, nil);
        revenant_advance(run, node, 2);
        revenant_expect_number("reversed move to does not move the node", node.position.x, 0);

        __block NSUInteger customCalls = 0;
        SCNAction *custom = [SCNAction customActionWithDuration:1 actionBlock:^(SCNNode *target, CGFloat elapsed) {
            customCalls++;
        }];
        SCNAction *again = custom.reversedAction;
        revenant_expect_number("reversed custom action keeps its duration", again.duration, 1);
        run = revenant_run(again, nil);
        revenant_advance(run, node, 1);
        revenant_check(customCalls > 0, "reversed custom action runs the same block", @"the block did not run");

        SCNAction *randomWait = [SCNAction waitForDuration:1 withRange:0.5];
        revenant_expect_number("random wait reports its average duration", randomWait.duration, 1);
        NSUInteger endedByOne = 0;
        NSUInteger runs = 500;
        BOOL earlyEnd = NO, lateStay = NO;
        for (NSUInteger index = 0; index < runs; index++) {
            node = [SCNNode node];
            run = revenant_run(randomWait, nil);
            if (revenant_advance(run, node, 0.74)) {
                earlyEnd = YES;
            }
            if (revenant_advance(run, node, 0.26)) {
                endedByOne++;
            }
            if (!revenant_advance(run, node, 0.25 + 0.01)) {
                lateStay = YES;
            }
        }
        revenant_check(!earlyEnd, "random wait does not end before half its range below the average", @"a run ended before 0.75 seconds");
        revenant_check(!lateStay, "random wait ends within half its range above the average", @"a run was still waiting at 1.26 seconds");
        revenant_check(endedByOne > 0 && endedByOne < runs, "random wait varies from run to run", @"every run ended at the same time");
        revenant_check(endedByOne > runs / 3 && endedByOne < 2 * runs / 3, "random wait is centred on the average", @"runs do not split around the average");

        SCNNode *parentWalk = [SCNNode node];
        node = [SCNNode node];
        [parentWalk addChildNode:node];
        run = revenant_run([SCNAction sequence:@[[SCNAction waitForDuration:1 withRange:0.5],
                                                  [SCNAction moveBy:SCNVector3Make(1, 0, 0) duration:1]]], nil);
        revenant_advance(run, node, 0.7);
        revenant_expect_number("sequence waits before the move when a random wait is in it", node.position.x, 0);
        revenant_advance(run, node, 1.8);
        revenant_expect_number("sequence with a random wait completes its move", node.position.x, 1);

        NSURL *clipURL = revenant_write_wave(@"scenekit_action_test.wav", 0.1);
        SCNAudioSource *clip = [[SCNAudioSource alloc] initWithURL:clipURL];
        SCNAction *spoken = [SCNAction playAudioSource:clip waitForCompletion:YES];
        revenant_expect_near("play audio that waits lasts as long as the audio", spoken.duration, 0.1, 0.02);
        SCNAction *silent = [SCNAction playAudioSource:clip waitForCompletion:NO];
        revenant_expect_near("play audio that does not wait completes at once", silent.duration, 0, 1e-6);
        SCNAction *reversedSpoken = spoken.reversedAction;
        revenant_check(reversedSpoken.revenantKind == RevenantSCNActionKindPlayAudio, "reversed play audio is the same action", @"the kind changed");
        revenant_expect_near("reversed play audio keeps its length", reversedSpoken.duration, 0.1, 0.02);

        revenant_added_players = [NSMutableArray array];
        RevenantFakeNode *fake = [RevenantFakeNode node];
        run = revenant_run(spoken, nil);
        revenant_check(!revenant_advance(run, fake, 0.05), "play audio runs while the audio plays", @"play audio ended early");
        revenant_check(revenant_added_players.count == 1, "play audio adds one player to its node", @"no player was added");
        revenant_check([revenant_added_players.firstObject revenantAVPlayer].isPlaying, "the node's player is playing", @"the player is not playing");
        revenant_check(revenant_advance(run, fake, 0.1), "play audio that waits ends with the audio", @"play audio is still running");
        [[NSFileManager defaultManager] removeItemAtURL:clipURL error:NULL];

        revenant_check(revenant_negative ? NO : YES, "negative control", @"the negative control is inverted");
    }
    return revenant_finish();
}
