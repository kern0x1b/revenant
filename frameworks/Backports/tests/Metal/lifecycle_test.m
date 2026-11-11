#import "../Foundation/check.h"
#import "RevenantMetalLifecycle.h"

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    RevenantMetalLifecycle state = {0};

    bool outer = RevenantMetalLifecycleAcquire(&state);
    revenant_check((outer && state.depth == 1) != revenant_negative, "an acquire in the foreground makes the context current and opens one level", @"an acquire in the foreground does not make the context current");

    bool inner = RevenantMetalLifecycleAcquire(&state);
    revenant_check((inner && state.depth == 2) != revenant_negative, "a nested acquire opens a second level", @"a nested acquire does not open a second level");

    revenant_check((!RevenantMetalLifecycleRelinquish(&state) && state.depth == 1) != revenant_negative, "an inner release keeps the level of the outer acquire", @"an inner release ends the outer acquire");

    revenant_check((RevenantMetalLifecycleRelinquish(&state) && state.depth == 0) != revenant_negative, "the outermost release is the one that releases the context", @"the outermost release does not release the context");

    revenant_check(RevenantMetalLifecycleSuspend(&state) != revenant_negative, "the first suspend begins a suspension", @"the first suspend does not begin a suspension");
    revenant_check((!RevenantMetalLifecycleSuspend(&state) && state.suspended) != revenant_negative, "a second suspend changes nothing", @"a second suspend begins another suspension");

    bool suspended = RevenantMetalLifecycleAcquire(&state);
    revenant_check((!suspended && state.depth == 1) != revenant_negative, "an acquire while suspended does not make the context current", @"an acquire while suspended makes the context current");

    revenant_check((RevenantMetalLifecycleRelinquish(&state) && state.depth == 0) != revenant_negative, "the release of an acquire taken while suspended is still the outermost one", @"the release of an acquire taken while suspended is not reported");

    revenant_check((!RevenantMetalLifecycleRelinquish(&state) && state.depth == 0) != revenant_negative, "an unbalanced release is refused and leaves the depth at zero", @"an unbalanced release changed the depth or was accepted");

    revenant_check(RevenantMetalLifecycleResume(&state) != revenant_negative, "the resume ends the suspension", @"the resume does not end the suspension");
    revenant_check((!RevenantMetalLifecycleResume(&state) && state.resumptions == 1) != revenant_negative, "a second resume changes nothing and the resumption is counted once", @"a second resume changed the resumptions");

    revenant_check((RevenantMetalLifecycleAcquire(&state) && RevenantMetalLifecycleRelinquish(&state)) != revenant_negative, "an acquire after the resume makes the context current again", @"an acquire after the resume does not make the context current");

    revenant_check((RevenantMetalLifecycleSuspend(&state) && RevenantMetalLifecycleResume(&state) && state.resumptions == 2) != revenant_negative, "each return from the background is counted", @"a second return from the background is not counted");

    return revenant_finish();
}
