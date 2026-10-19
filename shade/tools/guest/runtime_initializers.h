// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Invoke delayed guest dylib initializers through the firmware dyld
// interface.

#pragma once

// Completes the Darwin crt1 contract after Mach and cthread setup by asking
// the target dyld to invoke delayed module initializers for loaded dylibs.
void shade_guest_run_runtime_initializers(void);
