#import "RevenantHistoryPlan.h"

#include <stdio.h>

static const char *Name(RevenantHistoryMove move)
{
    switch (move) {
    case RevenantHistoryMoveEngine:
        return "engine";
    case RevenantHistoryMoveLoad:
        return "load";
    case RevenantHistoryMoveReplay:
        return "replay";
    }
    return "unknown";
}

int main(void)
{
    struct {
        BOOL targetIsSubstitute;
        BOOL engineHistoryTrusted;
        const char *label;
    } cases[] = {
        {NO, YES, "plain entry, engine trusted"},
        {NO, NO, "plain entry, engine not trusted"},
        {YES, YES, "string entry, engine trusted"},
        {YES, NO, "string entry, engine not trusted"},
    };
    for (size_t index = 0; index < sizeof cases / sizeof cases[0]; index++) {
        RevenantHistoryMove move = RevenantHistoryPlanMove(cases[index].targetIsSubstitute, cases[index].engineHistoryTrusted);
        printf("%s: %s\n", cases[index].label, Name(move));
    }
    return 0;
}
