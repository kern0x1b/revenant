#import "RevenantHistoryPlan.h"

RevenantHistoryMove RevenantHistoryPlanMove(BOOL targetIsSubstitute, BOOL engineHistoryTrusted)
{
    if (targetIsSubstitute)
        return RevenantHistoryMoveReplay;
    return engineHistoryTrusted ? RevenantHistoryMoveEngine : RevenantHistoryMoveLoad;
}
