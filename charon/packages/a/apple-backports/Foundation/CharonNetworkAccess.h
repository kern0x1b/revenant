#import <Foundation/Foundation.h>
#include <stdbool.h>

/* The port's own answer to "is the link under us a cellular one", shared by the network gate and by
   the session's metrics. Defined in CharonNetworkAccess.c, which exports no API symbol: a C function
   shared between backport files belongs beside neither of them. The override is the seam the gate
   uses to pin the answer. */
FOUNDATION_EXPORT int charon_network_cellular_override;
FOUNDATION_EXPORT bool charon_network_cellular(void);
