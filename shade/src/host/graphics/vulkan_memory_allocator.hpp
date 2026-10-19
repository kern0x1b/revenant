// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Configure Vulkan Memory Allocator for the renderer Vulkan API and
// loader contract.

#pragma once

// The renderer requests Vulkan 1.0, so keep VMA on the same API contract.
// Shade links the Vulkan loader directly and does not need VMA's dynamic
// function loading path.
#define VMA_VULKAN_VERSION 1000000
#define VMA_STATIC_VULKAN_FUNCTIONS 1
#define VMA_DYNAMIC_VULKAN_FUNCTIONS 0

#include <vk_mem_alloc.h>
