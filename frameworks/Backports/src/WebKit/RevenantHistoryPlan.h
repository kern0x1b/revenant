#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, RevenantHistoryMove) {
    RevenantHistoryMoveEngine,
    RevenantHistoryMoveLoad,
    RevenantHistoryMoveReplay,
};

RevenantHistoryMove RevenantHistoryPlanMove(BOOL targetIsSubstitute, BOOL engineHistoryTrusted);
