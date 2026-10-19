// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Define GLES constants shared by guest dispatch and renderer state.

#pragma once

#include <cstddef>
#include <cstdint>

namespace shade::gles_abi {

inline constexpr std::uint32_t no_error = 0;
inline constexpr std::uint32_t invalid_enum = 0x0500U;
inline constexpr std::uint32_t invalid_value = 0x0501U;
inline constexpr std::uint32_t invalid_operation = 0x0502U;
inline constexpr std::uint32_t out_of_memory = 0x0505U;

inline constexpr std::uint32_t texture_2d = 0x0de1U;
inline constexpr std::uint32_t texture_rectangle_apple = 0x84f5U;
inline constexpr std::uint32_t texture_min_filter = 0x2801U;
inline constexpr std::uint32_t texture_mag_filter = 0x2800U;
inline constexpr std::uint32_t texture_wrap_s = 0x2802U;
inline constexpr std::uint32_t texture_wrap_t = 0x2803U;
inline constexpr std::uint32_t nearest = 0x2600U;
inline constexpr std::uint32_t linear = 0x2601U;
inline constexpr std::uint32_t nearest_mipmap_nearest = 0x2700U;
inline constexpr std::uint32_t linear_mipmap_nearest = 0x2701U;
inline constexpr std::uint32_t nearest_mipmap_linear = 0x2702U;
inline constexpr std::uint32_t linear_mipmap_linear = 0x2703U;
inline constexpr std::uint32_t repeat = 0x2901U;
inline constexpr std::uint32_t clamp_to_edge = 0x812fU;
inline constexpr std::uint32_t mirrored_repeat = 0x8370U;
inline constexpr std::uint32_t framebuffer = 0x8d40U;
inline constexpr std::uint32_t renderbuffer = 0x8d41U;
inline constexpr std::uint32_t framebuffer_binding = 0x8ca6U;
inline constexpr std::uint32_t renderbuffer_binding = 0x8ca7U;
inline constexpr std::uint32_t color_attachment0 = 0x8ce0U;
inline constexpr std::uint32_t framebuffer_complete = 0x8cd5U;
inline constexpr std::uint32_t framebuffer_incomplete_attachment = 0x8cd6U;
inline constexpr std::uint32_t texture_binding_2d = 0x8069U;
inline constexpr std::uint32_t texture_binding_rectangle_apple = 0x84f6U;
inline constexpr std::uint32_t texture0 = 0x84c0U;
inline constexpr std::uint32_t active_texture = 0x84e0U;
inline constexpr std::uint32_t client_active_texture = 0x84e1U;
inline constexpr std::uint32_t maximum_texture_units = 0x84e2U;
inline constexpr std::uint32_t maximum_texture_image_units = 0x8872U;
inline constexpr std::size_t texture_unit_count = 4;
inline constexpr std::uint32_t fragment_shader = 0x8b30U;
inline constexpr std::uint32_t vertex_shader = 0x8b31U;
inline constexpr std::uint32_t delete_status = 0x8b80U;
inline constexpr std::uint32_t compile_status = 0x8b81U;
inline constexpr std::uint32_t link_status = 0x8b82U;
inline constexpr std::uint32_t validate_status = 0x8b83U;
inline constexpr std::uint32_t info_log_length = 0x8b84U;
inline constexpr std::uint32_t attached_shaders = 0x8b85U;
inline constexpr std::uint32_t active_uniforms = 0x8b86U;
inline constexpr std::uint32_t active_attributes = 0x8b89U;
inline constexpr std::uint32_t shader_source_length = 0x8b88U;
inline constexpr std::uint32_t shader_type = 0x8b4fU;
inline constexpr std::size_t maximum_vertex_attributes = 8;
inline constexpr std::uint32_t array_buffer = 0x8892U;
inline constexpr std::uint32_t element_array_buffer = 0x8893U;
inline constexpr std::uint32_t buffer_size = 0x8764U;
inline constexpr std::uint32_t buffer_usage = 0x8765U;

inline constexpr std::uint32_t pack_alignment = 0x0d05U;
inline constexpr std::uint32_t unpack_alignment = 0x0cf5U;
inline constexpr std::uint32_t unpack_row_length = 0x0cf2U;
inline constexpr std::uint32_t unpack_skip_rows = 0x0cf3U;
inline constexpr std::uint32_t unpack_skip_pixels = 0x0cf4U;
inline constexpr std::uint32_t unpack_row_bytes_apple = 0x8a16U;
inline constexpr std::uint32_t unpack_client_storage_apple = 0x85b2U;

inline constexpr std::uint32_t alpha = 0x1906U;
inline constexpr std::uint32_t rgb = 0x1907U;
inline constexpr std::uint32_t rgba = 0x1908U;
inline constexpr std::uint32_t luminance = 0x1909U;
inline constexpr std::uint32_t luminance_alpha = 0x190aU;
inline constexpr std::uint32_t bgra_apple = 0x80e1U;

inline constexpr std::uint32_t unsigned_byte = 0x1401U;
inline constexpr std::uint32_t byte = 0x1400U;
inline constexpr std::uint32_t short_type = 0x1402U;
inline constexpr std::uint32_t unsigned_short = 0x1403U;
inline constexpr std::uint32_t float_type = 0x1406U;
inline constexpr std::uint32_t fixed = 0x140cU;
inline constexpr std::uint32_t unsigned_short_4_4_4_4 = 0x8033U;
inline constexpr std::uint32_t unsigned_short_5_5_5_1 = 0x8034U;
inline constexpr std::uint32_t unsigned_short_5_6_5 = 0x8363U;

inline constexpr std::uint32_t static_draw = 0x88e4U;
inline constexpr std::uint32_t dynamic_draw = 0x88e8U;

inline constexpr std::uint32_t points = 0x0000U;
inline constexpr std::uint32_t lines = 0x0001U;
inline constexpr std::uint32_t line_loop = 0x0002U;
inline constexpr std::uint32_t line_strip = 0x0003U;
inline constexpr std::uint32_t triangles = 0x0004U;
inline constexpr std::uint32_t triangle_strip = 0x0005U;
inline constexpr std::uint32_t triangle_fan = 0x0006U;
inline constexpr std::uint32_t depth_buffer_bit = 0x00000100U;
inline constexpr std::uint32_t stencil_buffer_bit = 0x00000400U;
inline constexpr std::uint32_t color_buffer_bit = 0x00004000U;

inline constexpr std::uint32_t vertex_array = 0x8074U;
inline constexpr std::uint32_t color_array = 0x8076U;
inline constexpr std::uint32_t texture_coord_array = 0x8078U;
inline constexpr std::uint32_t blend = 0x0be2U;
inline constexpr std::uint32_t cull_face = 0x0b44U;
inline constexpr std::uint32_t scissor_test = 0x0c11U;

inline constexpr std::uint32_t current_color = 0x0b00U;
inline constexpr std::uint32_t line_width_query = 0x0b21U;
inline constexpr std::uint32_t matrix_mode_query = 0x0ba0U;
inline constexpr std::uint32_t viewport_query = 0x0ba2U;
inline constexpr std::uint32_t modelview_matrix_query = 0x0ba6U;
inline constexpr std::uint32_t projection_matrix_query = 0x0ba7U;
inline constexpr std::uint32_t texture_matrix_query = 0x0ba8U;
inline constexpr std::uint32_t scissor_box = 0x0c10U;
inline constexpr std::uint32_t color_write_mask = 0x0c23U;
inline constexpr std::uint32_t front_face_query = 0x0b46U;
inline constexpr std::uint32_t cull_face_mode = 0x0b45U;
inline constexpr std::uint32_t depth_write_mask = 0x0b72U;
inline constexpr std::uint32_t stencil_write_mask = 0x0b98U;
inline constexpr std::uint32_t maximum_texture_size = 0x0d33U;
inline constexpr std::uint32_t maximum_viewport_dimensions = 0x0d3aU;
inline constexpr std::uint32_t maximum_rectangle_texture_size_apple = 0x84f8U;

inline constexpr std::uint32_t modelview = 0x1700U;
inline constexpr std::uint32_t projection = 0x1701U;
inline constexpr std::uint32_t texture_matrix = 0x1702U;
inline constexpr std::uint32_t texture_source = 0x1702U;
inline constexpr std::size_t maximum_matrix_stack_depth = 32;

inline constexpr std::uint32_t zero = 0;
inline constexpr std::uint32_t one = 1;
inline constexpr std::uint32_t source_alpha = 0x0302U;
inline constexpr std::uint32_t one_minus_source_alpha = 0x0303U;
inline constexpr std::uint32_t destination_alpha = 0x0304U;
inline constexpr std::uint32_t one_minus_destination_alpha = 0x0305U;
inline constexpr std::uint32_t destination_color = 0x0306U;
inline constexpr std::uint32_t one_minus_destination_color = 0x0307U;
inline constexpr std::uint32_t source_alpha_saturate = 0x0308U;
inline constexpr std::uint32_t constant_color = 0x8001U;
inline constexpr std::uint32_t one_minus_constant_color = 0x8002U;
inline constexpr std::uint32_t constant_alpha = 0x8003U;
inline constexpr std::uint32_t one_minus_constant_alpha = 0x8004U;

inline constexpr std::uint32_t clockwise = 0x0900U;
inline constexpr std::uint32_t counter_clockwise = 0x0901U;
inline constexpr std::uint32_t front = 0x0404U;
inline constexpr std::uint32_t back = 0x0405U;
inline constexpr std::uint32_t front_and_back = 0x0408U;
inline constexpr std::uint32_t texture_environment = 0x2300U;
inline constexpr std::uint32_t texture_environment_mode = 0x2200U;
inline constexpr std::uint32_t texture_environment_color = 0x2201U;
inline constexpr std::uint32_t modulate = 0x2100U;
inline constexpr std::uint32_t replace = 0x1e01U;
inline constexpr std::uint32_t decal = 0x2101U;
inline constexpr std::uint32_t add = 0x0104U;
inline constexpr std::uint32_t combine = 0x8570U;
inline constexpr std::uint32_t combine_rgb = 0x8571U;
inline constexpr std::uint32_t combine_alpha = 0x8572U;
inline constexpr std::uint32_t rgb_scale = 0x8573U;
inline constexpr std::uint32_t add_signed = 0x8574U;
inline constexpr std::uint32_t interpolate = 0x8575U;
inline constexpr std::uint32_t constant = 0x8576U;
inline constexpr std::uint32_t primary_color = 0x8577U;
inline constexpr std::uint32_t previous = 0x8578U;
inline constexpr std::uint32_t subtract = 0x84e7U;
inline constexpr std::uint32_t source0_rgb = 0x8580U;
inline constexpr std::uint32_t source1_rgb = 0x8581U;
inline constexpr std::uint32_t source2_rgb = 0x8582U;
inline constexpr std::uint32_t source0_alpha = 0x8588U;
inline constexpr std::uint32_t source1_alpha = 0x8589U;
inline constexpr std::uint32_t source2_alpha = 0x858aU;
inline constexpr std::uint32_t operand0_rgb = 0x8590U;
inline constexpr std::uint32_t operand1_rgb = 0x8591U;
inline constexpr std::uint32_t operand2_rgb = 0x8592U;
inline constexpr std::uint32_t operand0_alpha = 0x8598U;
inline constexpr std::uint32_t operand1_alpha = 0x8599U;
inline constexpr std::uint32_t operand2_alpha = 0x859aU;
inline constexpr std::uint32_t source_color = 0x0300U;
inline constexpr std::uint32_t one_minus_source_color = 0x0301U;
inline constexpr std::uint32_t dot3_rgb = 0x86aeU;
inline constexpr std::uint32_t dot3_rgba = 0x86afU;
inline constexpr std::uint32_t alpha_scale = 0x0d1cU;

inline constexpr std::uint32_t default_pixel_alignment = 4;
inline constexpr std::uint32_t maximum_texture_dimension = 4096;
inline constexpr std::uint64_t maximum_resource_bytes =
    256ULL * 1024ULL * 1024ULL;
inline constexpr std::uint32_t maximum_draw_vertices = 1'000'000U;

} // namespace shade::gles_abi
