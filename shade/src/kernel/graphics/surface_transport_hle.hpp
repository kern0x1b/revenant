// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#pragma once

#include "foundation/userland_hle.hpp"
#include "graphics/surface_transport_abi.hpp"

namespace shade::surface_transport {

[[nodiscard]] inline Kind io_surface_kind(UserlandHleCall& call)
{
    const auto width = call.original_function_code("_IOSurfaceClientGetWidth", 8);
    const auto height = call.original_function_code("_IOSurfaceClientGetHeight", 8);
    return width && height ? io_surface_kind(*width, *height)
                           : Kind::IOSurfaceClient;
}

[[nodiscard]] inline const ClientAbi& loaded_client_abi(UserlandHleCall& call)
{
    return call.image_loaded(io_surface_client.image_suffix)
               ? for_kind(io_surface_kind(call))
               : core_surface_client_buffer;
}

} // namespace shade::surface_transport
