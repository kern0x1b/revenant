// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Adapt guest network configuration APIs to virtual interfaces and
// notifications.

#pragma once

namespace shade {

class UserlandHleCall;
class UserlandHleRegistry;

// Keeps the firmware's SystemConfiguration interface enumeration and IOKit
// object construction intact while avoiding an unbounded readiness wait when
// the legacy InterfaceNamer dynamic-store marker is absent.
class SystemConfigurationHle {
public:
    explicit SystemConfigurationHle(UserlandHleRegistry& registry);

private:
    void begin_interface_discovery(UserlandHleCall& call);
};

} // namespace shade
