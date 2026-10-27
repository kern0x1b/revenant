// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Connect desktop display, audio, control and resource adapters to a
// session.

#include "app/desktop_host.hpp"

#include <fstream>
#include <stdexcept>

#include "app/live_control.hpp"
#include "foundation/device_model.hpp"
#include "host/ffmpeg_audio_decoder.hpp"
#include "host/native_gles.hpp"
#include "host/resource_usage.hpp"
#include "app/sdl_audio_sink.hpp"
#include "app/sdl_display.hpp"
#include "kernel/snapshot_census.hpp"

namespace emulator {

DesktopHost::DesktopHost(std::filesystem::path census_output)
    : census_output_ { std::move(census_output) }
{
}

void DesktopHost::initialize_graphics() { register_native_gles_renderer(); }

void DesktopHost::session_stopped(const CompatibilityKernel& kernel,
    const AddressSpace& memory)
{
    if (census_output_.empty())
        return;
    std::ofstream out { census_output_ };
    if (!out) {
        throw std::runtime_error {
            "cannot write census output: " + census_output_.string()
        };
    }
    for (const auto& name : CompatibilityKernelSnapshot::populated_members(kernel))
        out << name << '\n';
    for (const auto& name : CompatibilityKernelSnapshot::populated_memory(memory))
        out << name << '\n';
    out.flush();
    if (!out) {
        throw std::runtime_error {
            "cannot flush census output: " + census_output_.string()
        };
    }
}

std::unique_ptr<DisplayPresenter> DesktopHost::create_display(
    const DeviceModel& device)
{
    if (!SdlDisplay::available()) {
        throw std::runtime_error {
            "--display sdl requested, but SDL2 support is not built"
        };
    }
    return std::make_unique<SdlDisplay>(
        device.screen.panel, device.screen.user_interface);
}

std::unique_ptr<ControlChannel> DesktopHost::create_control(
    const DeviceModel& device)
{
    return std::make_unique<LiveControl>(
        0, device.screen.user_interface, device.input.system_gestures);
}

SessionAudio DesktopHost::create_audio()
{
    SessionAudio result;
    if (SdlAudioSink::available()) {
        result.sink = std::make_shared<SdlAudioSink>();
        result.backend_name = "sdl";
    }
    if (FfmpegAudioDecoder::available()) {
        result.decoder = std::make_shared<FfmpegAudioDecoder>();
        result.decoder_name = "ffmpeg";
    }
    return result;
}

HostMemorySnapshot DesktopHost::memory_snapshot() const
{
    return host_memory_snapshot();
}

HostMemoryBudgetSnapshot DesktopHost::memory_budget_snapshot() const
{
    return host_memory_budget_snapshot();
}

}
