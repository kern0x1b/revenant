// Host probe: a private integer property on a client, ports and endpoints, as the library's identity of the objects it owns
// (the program is stamp.h; the 6.1.3 application runs the same code). Run it through `sh ../prefs-bracket.sh run`: it creates
// process-lifetime virtual endpoints and nothing that persists (the host-probe rule of prefs-bracket.sh).
#include "stamp.h"

int main(void)
{
    @autoreleasepool {
        charon_stamp_probe();
    }
    return 0;
}
