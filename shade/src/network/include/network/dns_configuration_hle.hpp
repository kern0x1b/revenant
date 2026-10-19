// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Expose the virtual DNS configuration through the guest resolver
// boundary.
//
// Apple public ABI/behavior references (guest profiles may differ):
// https://github.com/apple-oss-distributions/configd/blob/configd-137.3/dnsinfo/dnsinfo.h

#pragma once

namespace shade {

class UserlandHleRegistry;

// Supplies the firmware mDNSResponder with the deterministic virtual DNS
// endpoint without creating resolver files inside the guest root filesystem.
void register_dns_configuration_hle(UserlandHleRegistry& registry);

} // namespace shade
