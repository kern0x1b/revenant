#import "RevenantTextFieldAlignment.h"

static const long RevenantAlignmentCenter = 0;
static const long RevenantAlignmentTop = 1;

long RevenantTextFieldInitialAlignment(long current)
{
    return current == RevenantAlignmentTop ? RevenantAlignmentCenter : current;
}
