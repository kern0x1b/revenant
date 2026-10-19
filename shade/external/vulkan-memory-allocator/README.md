# Vulkan Memory Allocator

This directory vendors AMD's Vulkan Memory Allocator 3.4.0 as an unmodified
single-header dependency.

- Upstream: https://github.com/GPUOpen-LibrariesAndSDKs/VulkanMemoryAllocator
- Release: `v3.4.0`
- Header SHA-256:
  `8487b7995ad3b263eb73bc5b9a77d71aa69b6bef5d58a715c02d2663afd81f1a`
- License SHA-256:
  `52df2c03d6cfc9ffec13c9d3626c530fc9ce0cbe41d5ea3d10cd46edeb1aeb38`
- License: MIT; see `LICENSE.txt`.

The dependency is used only by the host Vulkan renderer. It does not become
part of a guest firmware filesystem.
