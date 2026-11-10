#include "../revenant_impl.h"
#import "RevenantOSLog.h"
#include <os/log.h>

static struct os_log_s revenant_os_log_default_instance = {
    .isa = NULL,
    .subsystem = "",
    .category = ""
};

os_log_t __revenant_fb___os_log_default = (os_log_t)&revenant_os_log_default_instance;