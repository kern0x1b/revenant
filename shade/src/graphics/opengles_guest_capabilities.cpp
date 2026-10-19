// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Resolve guest GPU capabilities without exposing host renderer
// identity.

#include "graphics/opengles_guest_capabilities.hpp"

#include "foundation/userland_hle.hpp"

namespace shade {
namespace {

    constexpr std::string_view common_vendor { "Imagination Technologies" };
    constexpr std::string_view common_renderer {
        "PowerVR MBXLite with VGPLite"
    };
    constexpr std::string_view common_version { "OpenGL ES-CM 1.1" };
    constexpr std::string_view sgx535_renderer { "PowerVR SGX 535" };
    constexpr std::string_view sgx535_version {
        "OpenGL ES-CM 1.1 IMGSGX535-31.4"
    };

    constexpr OpenGlesGuestCapabilities legacy_mbx_lite {
        "mbx-lite-legacy",
        common_vendor,
        common_renderer,
        common_version,
        "GL_APPLE_client_storage GL_APPLE_texture_rectangle "
        "GL_IMG_read_format GL_IMG_texture_compression_pvrtc "
        "GL_IMG_texture_env_enhanced_fixed_function "
        "GL_IMG_texture_format_BGRA8888 GL_IMG_texture_stream "
        "GL_IMG_user_clip_planes GL_IMG_vertex_program "
        "GL_OES_byte_coordinates GL_OES_compressed_paletted_texture "
        "GL_OES_draw_texture GL_OES_fixed_point GL_OES_matrix_palette "
        "GL_OES_point_size_array GL_OES_point_sprite GL_OES_query_matrix "
        "GL_OES_read_format GL_OES_single_precision",
        2048,
        2048,
    };

    constexpr OpenGlesGuestCapabilities framebuffer_object_mbx_lite {
        "mbx-lite-framebuffer-object",
        common_vendor,
        common_renderer,
        common_version,
        "GL_EXT_texture_filter_anisotropic GL_EXT_texture_lod_bias "
        "GL_IMG_read_format GL_IMG_texture_compression_pvrtc "
        "GL_IMG_texture_format_BGRA8888 GL_OES_blend_subtract "
        "GL_OES_compressed_paletted_texture GL_OES_depth24 "
        "GL_OES_draw_texture GL_OES_framebuffer_object GL_OES_mapbuffer "
        "GL_OES_matrix_palette GL_OES_point_size_array GL_OES_point_sprite "
        "GL_OES_read_format GL_OES_rgb8_rgba8 "
        "GL_OES_texture_mirrored_repeat GL_APPLE_client_storage "
        "GL_APPLE_core_surface_texture GL_APPLE_texture_rectangle",
        2048,
        2048,
    };

    // The 7A341 SGX535 driver exposes both ES 1.1 and ES 2.0 strings. The HLE
    // implements the fixed-function ES 1.1 ABI today, so keep the ES 2.0 shader
    // capability private until that ABI is implemented instead of advertising a
    // path that would fail after context creation.
    constexpr OpenGlesGuestCapabilities sgx535 {
        "sgx535-fixed-function",
        common_vendor,
        sgx535_renderer,
        sgx535_version,
        "GL_EXT_texture_filter_anisotropic GL_EXT_texture_lod_bias "
        "GL_IMG_read_format GL_IMG_texture_compression_pvrtc "
        "GL_IMG_texture_format_BGRA8888 GL_OES_blend_subtract "
        "GL_OES_compressed_paletted_texture GL_OES_depth24 "
        "GL_OES_draw_texture GL_OES_framebuffer_object GL_OES_mapbuffer "
        "GL_OES_matrix_palette GL_OES_point_size_array GL_OES_point_sprite "
        "GL_OES_read_format GL_OES_rgb8_rgba8 "
        "GL_OES_texture_mirrored_repeat GL_APPLE_client_storage "
        "GL_APPLE_core_surface_texture GL_APPLE_texture_rectangle",
        2048,
        2048,
    };

    constexpr OpenGlesGuestCapabilities sgx535_framebuffer_objects {
        "sgx535-framebuffer-object",
        common_vendor,
        sgx535_renderer,
        sgx535_version,
        sgx535.extensions,
        sgx535.maximum_texture_dimension,
        sgx535.maximum_viewport_dimension,
    };

    // Share the implemented SGX fixed-function contract; hardware identity
    // stays separate from the host Vulkan renderer and from ES 2 support.
    constexpr OpenGlesGuestCapabilities sgx543 = [] {
        auto capabilities = sgx535_framebuffer_objects;
        capabilities.name = "sgx543-framebuffer-object";
        capabilities.texture_units = 4;
        capabilities.renderer = "PowerVR SGX 543";
        capabilities.version = "OpenGL ES-CM 1.1";
        return capabilities;
    }();

} // namespace

EaglContextAbi detect_eagl_context_abi(const UserlandHleCall& call)
{
    // Stripped framework builds retain the C macro-context accessor even
    // when the Objective-C implementation name is absent from the symbol table.
    return (call.symbol_address("-[EAGLContext GetMacroContextPrivate]") ||
               call.symbol_address("_EAGLGetCurrentMacroContextPrivate"))
               ? EaglContextAbi::FirmwareMacroDispatch
               : EaglContextAbi::HostManagedPublicAbi;
}

const OpenGlesGuestCapabilities& open_gles_guest_capabilities(
    OpenGlesGuestCapabilitySet kind)
{
    switch (kind) {
    case OpenGlesGuestCapabilitySet::MbxLiteLegacy:
        return legacy_mbx_lite;
    case OpenGlesGuestCapabilitySet::MbxLiteFramebufferObjects:
        return framebuffer_object_mbx_lite;
    case OpenGlesGuestCapabilitySet::Sgx535:
        return sgx535;
    case OpenGlesGuestCapabilitySet::Sgx535FramebufferObjects:
        return sgx535_framebuffer_objects;
    case OpenGlesGuestCapabilitySet::Sgx543:
        return sgx543;
    }
    return legacy_mbx_lite;
}

OpenGlesGuestCapabilitySet open_gles_framebuffer_capabilities(
    OpenGlesGuestCapabilitySet kind)
{
    switch (kind) {
    case OpenGlesGuestCapabilitySet::MbxLiteLegacy:
    case OpenGlesGuestCapabilitySet::MbxLiteFramebufferObjects:
        return OpenGlesGuestCapabilitySet::MbxLiteFramebufferObjects;
    case OpenGlesGuestCapabilitySet::Sgx535:
    case OpenGlesGuestCapabilitySet::Sgx535FramebufferObjects:
        return OpenGlesGuestCapabilitySet::Sgx535FramebufferObjects;
    case OpenGlesGuestCapabilitySet::Sgx543:
        return OpenGlesGuestCapabilitySet::Sgx543;
    }
    return OpenGlesGuestCapabilitySet::MbxLiteFramebufferObjects;
}

} // namespace shade
