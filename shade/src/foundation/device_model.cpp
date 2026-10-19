// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Describe virtual hardware identities, capabilities and device
// configuration profiles.

#include "foundation/device_model.hpp"

#include <array>

namespace shade {

namespace {

    constexpr std::array<DeviceModel, 10> models {
        DeviceModel {
            .identity = {
                .product_type = "iPhone1,1",
                .board_config = "M68AP",
                .activation_hardware_model = "M68DEV",
                .model_number = "MA712LL",
                .activation_hardware_model_policy =
                    ActivationHardwareModelPolicy::DevelopmentBoard,
            },
            .processor = {
                .soc = "Samsung S5L8900 (APL0098)",
                .model = ArmCpuModelKind::Arm1176JzfS,
                .bus_hz = 100'000'000,
                .topology = GuestCpuTopology::single_core(400'000'000U,
                    GuestCpuPerformanceClass::Legacy,
                    guest_cpu_isa::armv6k | guest_cpu_isa::thumb, 1U),
            },
            .memory = {
                .ram_bytes = 128ULL * 1024ULL * 1024ULL,
                .storage_bytes = 8ULL * 1024ULL * 1024ULL * 1024ULL,
            },
            .screen = {
                .panel = default_display_geometry,
                .accelerator = GraphicsAcceleratorKind::MbxLite,
                .framebuffer_service_class = "AppleH1CLCD",
                .graphics_services = {
                    .device_name = "iPhone",
                    .marketing_name = "iPhone",
                    .supports_multitasking = false,
                    .supports_cellular_data = true,
                },
            },
            .keybag = legacy_keybag_capabilities,
            .baseband = {
                .transport = BasebandTransport::Offline,
                .device_available = true,
            },
        },
        DeviceModel {
            .identity = {
                .product_type = "iPhone1,2",
                .board_config = "N82AP",
                .activation_hardware_model = "N82DEV",
                .model_number = "MB046",
            },
            .processor = {
                .soc = "Samsung S5L8900 (APL0098)",
                .model = ArmCpuModelKind::Arm1176JzfS,
                .bus_hz = 100'000'000,
                .topology = GuestCpuTopology::single_core(412'000'000U,
                    GuestCpuPerformanceClass::Legacy,
                    guest_cpu_isa::armv6k | guest_cpu_isa::thumb, 2U),
            },
            .memory = {
                .ram_bytes = 128ULL * 1024ULL * 1024ULL,
                .storage_bytes = 8ULL * 1024ULL * 1024ULL * 1024ULL,
            },
            .screen = {
                .panel = default_display_geometry,
                .accelerator = GraphicsAcceleratorKind::MbxLite,
                .framebuffer_service_class = "AppleH1CLCD",
                .graphics_services = {
                    .device_name = "iPhone",
                    .marketing_name = "iPhone 3G",
                    .supports_multitasking = false,
                    .supports_cellular_data = true,
                },
            },
            // iPhone OS 4 still routes its no-passcode bootstrap through the
            // AppleKeyStore contract.  The service is virtualized here; the
            // model describes the guest capability rather than physical
            // silicon.
            .keybag = virtual_keybag_capabilities,
            .baseband = {
                .transport = BasebandTransport::Offline,
                .device_available = true,
            },
        },
        DeviceModel {
            .identity = {
                .product_type = "iPhone2,1",
                .board_config = "N88AP",
                .activation_hardware_model = "N88DEV",
                .model_number = "MB715",
            },
            .processor = {
                .soc = "Samsung S5L8920",
                .model = ArmCpuModelKind::CortexA8,
                .bus_hz = 100'000'000,
                .topology = GuestCpuTopology::single_core(600'000'000U,
                    GuestCpuPerformanceClass::Performance,
                    guest_cpu_isa::armv7 | guest_cpu_isa::thumb |
                        guest_cpu_isa::thumb2,
                    3U),
            },
            .memory = {
                .ram_bytes = 256ULL * 1024ULL * 1024ULL,
                .storage_bytes = 16ULL * 1024ULL * 1024ULL * 1024ULL,
            },
            .screen = {
                .panel = default_display_geometry,
                .accelerator = GraphicsAcceleratorKind::Sgx535,
                .framebuffer_service_class = "AppleM2CLCD",
                .graphics_services = {
                    .device_name = "iPhone",
                    .marketing_name = "iPhone 3GS",
                    .supports_multitasking = true,
                    .supports_cellular_data = true,
                },
            },
            .keybag = virtual_keybag_capabilities,
            .baseband = {
                .transport = BasebandTransport::Offline,
                .device_available = false,
            },
        },
        DeviceModel {
            .identity = {
                .product_type = "iPhone3,1",
                .board_config = "N90AP",
                .activation_hardware_model = "N90DEV",
                .model_number = "MC603",
            },
            .processor = {
                .soc = "Apple A4 (S5L8930)",
                .model = ArmCpuModelKind::CortexA8,
                .bus_hz = 100'000'000,
                .topology = GuestCpuTopology::single_core(1'000'000'000U,
                    GuestCpuPerformanceClass::Performance,
                    guest_cpu_isa::armv7 | guest_cpu_isa::thumb |
                        guest_cpu_isa::thumb2,
                    7U),
            },
            .memory = {
                .ram_bytes = 512ULL * 1024ULL * 1024ULL,
                .storage_bytes = 16ULL * 1024ULL * 1024ULL * 1024ULL,
            },
            .screen = {
                .panel = DisplayGeometry { 640U, 960U },
                .user_interface = DisplayGeometry { 320U, 480U },
                .accelerator = GraphicsAcceleratorKind::Sgx535,
                .framebuffer_service_class = "AppleCLCD",
                .graphics_services = {
                    .device_name = "iPhone",
                    .marketing_name = "iPhone 4",
                    .supports_multitasking = true,
                    .supports_cellular_data = true,
                },
            },
            .keybag = virtual_keybag_capabilities,
            .baseband = {
                .transport = BasebandTransport::Offline,
                .device_available = true,
            },
        },
        DeviceModel {
            .identity = {
                .product_type = "iPhone4,1",
                .board_config = "N94AP",
                .activation_hardware_model = "N94DEV",
                .model_number = "MD235",
                .activation_hardware_model_policy =
                    ActivationHardwareModelPolicy::Retail,
            },
            .processor = {
                .soc = "Apple A5 (S5L8940)",
                .model = ArmCpuModelKind::CortexA9,
                .bus_hz = 100'000'000,
                .topology = GuestCpuTopology::symmetric_cores(2U, 800'000'000U,
                    GuestCpuPerformanceClass::Performance,
                    guest_cpu_isa::armv7 | guest_cpu_isa::thumb |
                        guest_cpu_isa::thumb2,
                    8U),
            },
            .memory = {
                .ram_bytes = 512ULL * 1024ULL * 1024ULL,
                .storage_bytes = 16ULL * 1024ULL * 1024ULL * 1024ULL,
            },
            .screen = {
                .panel = DisplayGeometry { 640U, 960U },
                .user_interface = DisplayGeometry { 320U, 480U },
                .accelerator = GraphicsAcceleratorKind::Sgx543,
                .framebuffer_service_class = "AppleM2CLCD",
                .graphics_services = {
                    .device_name = "iPhone",
                    .marketing_name = "iPhone 4S",
                    .supports_multitasking = true,
                    .supports_cellular_data = true,
                },
                .external_framebuffer = {
                    .service_class = "AppleM2TVOut",
                    .geometry = { 720U, 480U },
                },
            },
            .keybag = virtual_keybag_capabilities,
            .baseband = {
                .transport = BasebandTransport::Offline,
                .device_available = true,
            },
            .audio = AudioHardwareProfile::CodecBasebandVoiceRouting,
        },
        DeviceModel {
            .identity = {
                .product_type = "iPod1,1",
                .board_config = "N45AP",
                .activation_hardware_model = "N45DEV",
                .model_number = "MA623",
            },
            .processor = {
                .soc = "Samsung S5L8900 (APL0098)",
                .model = ArmCpuModelKind::Arm1176JzfS,
                .bus_hz = 100'000'000,
                .topology = GuestCpuTopology::single_core(412'000'000U,
                    GuestCpuPerformanceClass::Legacy,
                    guest_cpu_isa::armv6k | guest_cpu_isa::thumb, 5U),
            },
            .memory = {
                .ram_bytes = 128ULL * 1024ULL * 1024ULL,
                .storage_bytes = 8ULL * 1024ULL * 1024ULL * 1024ULL,
            },
            .screen = {
                .panel = default_display_geometry,
                .accelerator = GraphicsAcceleratorKind::MbxLite,
                .framebuffer_service_class = "AppleH1CLCD",
                .graphics_services = {
                    .device_name = "iPod",
                    .marketing_name = "iPod touch",
                    .supports_multitasking = false,
                    .supports_cellular_data = false,
                },
            },
            .keybag = legacy_keybag_capabilities,
            .baseband = {
                .transport = BasebandTransport::Offline,
                .device_available = false,
            },
        },
        DeviceModel {
            .identity = {
                .product_type = "iPod2,1",
                .board_config = "N72AP",
                .activation_hardware_model = "N72DEV",
                .model_number = "MB528",
            },
            .processor = {
                .soc = "Samsung S5L8720",
                .model = ArmCpuModelKind::Arm1176JzfS,
                .bus_hz = 100'000'000,
                .topology = GuestCpuTopology::single_core(533'000'000U,
                    GuestCpuPerformanceClass::Legacy,
                    guest_cpu_isa::armv6k | guest_cpu_isa::thumb, 6U),
            },
            .memory = {
                .ram_bytes = 128ULL * 1024ULL * 1024ULL,
                .storage_bytes = 8ULL * 1024ULL * 1024ULL * 1024ULL,
            },
            .screen = {
                .panel = default_display_geometry,
                .accelerator = GraphicsAcceleratorKind::MbxLite,
                .framebuffer_service_class = "AppleH1CLCD",
                .graphics_services = {
                    .device_name = "iPod",
                    .marketing_name = "iPod touch",
                    .supports_multitasking = false,
                    .supports_cellular_data = false,
                },
            },
            .keybag = legacy_keybag_capabilities,
            .baseband = {
                .transport = BasebandTransport::Offline,
                .device_available = false,
            },
        },
        DeviceModel {
            .identity = {
                .product_type = "iPod4,1",
                .board_config = "N81AP",
                .activation_hardware_model = "N81DEV",
                .model_number = "MC540",
            },
            .processor = {
                .soc = "Apple A4 (S5L8930)",
                .model = ArmCpuModelKind::CortexA8,
                .bus_hz = 100'000'000,
                .topology = GuestCpuTopology::single_core(1'000'000'000U,
                    GuestCpuPerformanceClass::Performance,
                    guest_cpu_isa::armv7 | guest_cpu_isa::thumb |
                        guest_cpu_isa::thumb2,
                    10U),
            },
            .memory = {
                .ram_bytes = 256ULL * 1024ULL * 1024ULL,
                .storage_bytes = 8ULL * 1024ULL * 1024ULL * 1024ULL,
            },
            .screen = {
                .panel = DisplayGeometry { 640U, 960U },
                .user_interface = DisplayGeometry { 320U, 480U },
                .accelerator = GraphicsAcceleratorKind::Sgx535,
                .framebuffer_service_class = "AppleCLCD",
                .graphics_services = {
                    .device_name = "iPod",
                    .marketing_name = "iPod touch",
                    .supports_multitasking = true,
                    .supports_cellular_data = false,
                },
            },
            .keybag = virtual_keybag_capabilities,
            .baseband = {
                .transport = BasebandTransport::Offline,
                .device_available = false,
            },
        },
        DeviceModel {
            .identity = {
                .product_type = "iPad1,1",
                .board_config = "K48AP",
                .activation_hardware_model = "K48DEV",
                .model_number = "MB292LL",
                .activation_hardware_model_policy =
                    ActivationHardwareModelPolicy::Retail,
            },
            .processor = {
                .soc = "Apple A4 (S5L8930)",
                .model = ArmCpuModelKind::CortexA8,
                .bus_hz = 100'000'000,
                .topology = GuestCpuTopology::single_core(1'000'000'000U,
                    GuestCpuPerformanceClass::Performance,
                    guest_cpu_isa::armv7 | guest_cpu_isa::thumb |
                        guest_cpu_isa::thumb2,
                    4U),
            },
            .memory = {
                .ram_bytes = 256ULL * 1024ULL * 1024ULL,
                .storage_bytes = 16ULL * 1024ULL * 1024ULL * 1024ULL,
                .usable_ram_bytes = 247ULL * 1024ULL * 1024ULL,
            },
            .screen = {
                .panel = DisplayGeometry { 768U, 1024U },
                .accelerator = GraphicsAcceleratorKind::Sgx535,
                .framebuffer_service_class = "AppleM2CLCD",
                .graphics_services = {
                    .device_name = "iPad",
                    .marketing_name = "iPad",
                    .supports_multitasking = true,
                    .supports_cellular_data = false,
                },
            },
            .input = {
                .system_gestures = classic_centered_tablet_system_gestures,
            },
            .keybag = virtual_keybag_capabilities,
            .baseband = {
                .transport = BasebandTransport::Offline,
                .device_available = false,
            },
        },
        DeviceModel {
            .identity = {
                .product_type = "iPad2,1",
                .board_config = "K93AP",
                .activation_hardware_model = "K93DEV",
                .model_number = "MC770",
                .activation_hardware_model_policy =
                    ActivationHardwareModelPolicy::Retail,
            },
            .processor = {
                .soc = "Apple A5 (S5L8940)",
                .model = ArmCpuModelKind::CortexA9,
                .bus_hz = 100'000'000,
                .topology = GuestCpuTopology::symmetric_cores(2U, 1'000'000'000U,
                    GuestCpuPerformanceClass::Performance,
                    guest_cpu_isa::armv7 | guest_cpu_isa::thumb | guest_cpu_isa::thumb2,
                    9U),
            },
            .memory = {
                .ram_bytes = 512ULL * 1024ULL * 1024ULL,
                .storage_bytes = 32ULL * 1024ULL * 1024ULL * 1024ULL,
            },
            .screen = {
                .panel = DisplayGeometry { 768U, 1024U },
                .accelerator = GraphicsAcceleratorKind::Sgx543,
                .framebuffer_service_class = "AppleM2CLCD",
                .graphics_services = {
                    .device_name = "iPad",
                    .marketing_name = "iPad 2",
                    .supports_multitasking = true,
                    .supports_cellular_data = false,
                },
                .external_framebuffer = {
                    .service_class = "AppleM2TVOut",
                    .geometry = { 720U, 480U },
                },
            },
            .input = {
                .system_gestures = classic_centered_tablet_system_gestures,
            },
            .keybag = virtual_keybag_capabilities,
            .baseband = {
                .transport = BasebandTransport::Offline,
                .device_available = false,
            },
            .ambient_light_sensor = {
                .service_class = "AppleEmbeddedI2CLightSensor",
                .channel0_gain = 1U,
                .channel1_gain = 1U,
                .integration_cycles = 1U,
            },
        },
    };

} // namespace

const DeviceModel& DeviceModel::default_model() { return models.front(); }

std::span<const DeviceModel> DeviceModel::available_models() { return models; }

const DeviceModel* DeviceModel::find(std::string_view product_type)
{
    for (const auto& model : models) {
        if (model.identity.product_type == product_type) {
            return &model;
        }
    }
    return nullptr;
}

} // namespace shade
