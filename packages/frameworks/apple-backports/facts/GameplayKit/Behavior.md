# Behaviours and goals

`GKBehavior` and `GKGoal`. GameplayKit.framework carries no code at all before iOS 8, the SDK declares
both at 9.0 (`GK_BASE_AVAILABILITY` is `NS_CLASS_AVAILABLE(10_11, 9_0)`), and the 6.1.3 armv7 cache
exports no GameplayKit class at all. Both are therefore this port's own, measured against the host's own
by `tests/backports/host/gameplaykit-core/measure.m` and held to it by `differential.m`.

- The goals are in the order they were added: `-goalCount`, `-objectAtIndexedSubscript:` and the fast
  enumeration all walk that order, `-weightForGoal:` of a goal the behaviour does not have is 0,
  `-objectForKeyedSubscript:` of an absent goal is nil, and `-setObject:forKeyedSubscript:` with a
  weight adds the goal if it is not there. `-copy` is a new behaviour with the same goals in the same
  order and the same weights. Setting a weight for a goal the behaviour already has changes the weight
  and does not add a second goal.
- `+behaviorWithGoals:` gives every goal a weight of 1.
- `+behaviorWithGoals:andWeights:` reads the weights **by the goal's own index** and does not pad: with
  fewer weights than goals the weights array raises `NSRangeException` at the first index it does not
  have, and a `nil` weights array leaves every goal weighing nothing, because a subscript of nil is nil
  and a subscript of an empty array raises. Every combination of up to three goals and up to three
  weights was measured, and all sixteen answers follow from that one loop. The archived version padded a
  short weights array with 1.0 instead, which is a rule of its own that the host does not have.
- `+behaviorWithWeightedGoals:` takes the weights the dictionary carries, which is what the method is
  for, and the host agrees on this host: a dictionary of one goal at weight 3 gives that goal weight 3.
  A first reading of the host, recorded in the archived series of 2026-09-30, found a weight of 0 for
  every goal and read it as a factory that dropped its weights; that does not reproduce on macOS 27
  (26A428), and the port and the host now answer the same. The earlier measurement is here because a
  later reader must not have to rediscover that it was a stale reading rather than a deliberate
  divergence.
- The weights are held beside the goals rather than in a dictionary keyed by them: a behaviour holds a
  handful of goals, so a scan is cheap, and the goals are matched by identity, which is what an
  application means when it asks for the weight of a goal it made.

A goal's own surface is its twelve factories and its copy, and an application builds one, hands it to a
behaviour with a weight, and an agent reads it, so nothing else of a goal is public. What a goal holds
here is the kind its factory names and the arguments it was given, and `GKAgent` reads them back when it
decides:

| factory | carries |
| --- | --- |
| `goalToSeekAgent:`, `goalToFleeAgent:` | one agent |
| `goalToAvoidObstacles:maxPredictionTime:` | a list of obstacles and the longest time to look ahead |
| `goalToAvoidAgents:maxPredictionTime:` | a list of agents and the longest time to look ahead |
| `goalToSeparateFromAgents:maxDistance:maxAngle:`, `goalToAlignWithAgents:maxDistance:maxAngle:`, `goalToCohereWithAgents:maxDistance:maxAngle:` | a list of agents, the distance beyond which an agent is ignored, and the angle beyond which its direction of travel is ignored |
| `goalToReachTargetSpeed:` | one speed |
| `goalToWander:` | one speed |
| `goalToInterceptAgent:maxPredictionTime:` | one agent and the longest time to look ahead |
| `goalToFollowPath:maxPredictionTime:forward:` | a path, the longest time to look ahead, and whether to follow it forwards |
| `goalToStayOnPath:maxPredictionTime:` | a path and the longest time to look ahead |

What is not here: nothing of the two classes. The members that need a `GKAgent`, a `GKObstacle` or a
`GKPath` to do anything with are carried, and a goal only carries the reference; an agent that reads
them arrives with the agent family.