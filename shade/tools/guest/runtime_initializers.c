// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Invoke delayed guest dylib initializers through the firmware dyld
// interface.

#include "runtime_initializers.h"

typedef int (*dyld_function_lookup)(char* name, unsigned long* address);
typedef void (*module_initializer)(void);

// Populated by the target dyld through the executable's __DATA,__dyld vector.
extern unsigned long shade_dyld_function_lookup_pointer;

void shade_guest_run_runtime_initializers(void)
{
    static char initializer_name[] =
        "__dyld_make_delayed_module_initializer_calls";
    dyld_function_lookup lookup =
        (dyld_function_lookup)(shade_dyld_function_lookup_pointer);
    unsigned long initializer_address = 0;
    if (lookup != (dyld_function_lookup)0 &&
        lookup(initializer_name, &initializer_address) != 0 &&
        initializer_address != 0) {
        ((module_initializer)initializer_address)();
    }
}
