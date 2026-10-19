// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Adapt guest network configuration APIs to virtual interfaces and
// notifications.

#pragma once

namespace emulator {

class UserlandHleCall;
class UserlandHleRegistry;

class SystemConfigurationHle {
public:
    explicit SystemConfigurationHle(UserlandHleRegistry& registry);

private:
    void begin_interface_discovery(UserlandHleCall& call);
};

}
