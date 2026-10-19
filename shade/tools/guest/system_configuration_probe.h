// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Exercise guest dynamic-store and reachability callbacks on the
// firmware run loop.

#pragma once

// Runs through the target firmware's public SystemConfiguration framework.
// Returns zero only after the dynamic-store and reachability callbacks have
// both executed on the guest CoreFoundation run loop.
int shade_run_system_configuration_probe(const char* reachability_name);
