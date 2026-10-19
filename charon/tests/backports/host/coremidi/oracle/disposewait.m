// Host probe: whether the release's dispose waits for a running read procedure (the program is disposewait.h; the 6.1.3 application
// runs the same code). Run it through `sh ../prefs-bracket.sh run`: it creates process-lifetime virtual endpoints and connects a
// port to one, and nothing that persists (the host-probe rule of prefs-bracket.sh).
#include "disposewait.h"

int main(void)
{
    @autoreleasepool {
        charon_dispose_wait_probe();
    }
    return 0;
}
