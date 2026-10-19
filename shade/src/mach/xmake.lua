-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

target("shade_xnu_adapter")
    set_kind("static")
    add_files("adapter/xnu_mig_adapter.cpp")

target("shade_mach")
    set_kind("static")
    add_files("guest_dispatch_policy.cpp", "guest_execution_policy.cpp", "guest_parallelism_policy.cpp",
              "mach_namespace.cpp", "xnu_scheduler.cpp")
    add_deps("shade_foundation", "shade_xnu_adapter", {public = true})
