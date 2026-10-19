// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Build virtual audio device identities and registry properties.

#include "kernel/kernel_iokit_audio_device_catalog.hpp"

#include <algorithm>
#include <array>

namespace shade::kernel_iokit::audio {
namespace {

    constexpr std::uint32_t four_cc(
        char first, char second, char third, char fourth)
    {
        return static_cast<std::uint32_t>(static_cast<unsigned char>(first))
                   << 24U |
               static_cast<std::uint32_t>(static_cast<unsigned char>(second))
                   << 16U |
               static_cast<std::uint32_t>(static_cast<unsigned char>(third))
                   << 8U |
               static_cast<std::uint32_t>(static_cast<unsigned char>(fourth));
    }

    constexpr std::uint32_t linear_pcm_format = four_cc('l', 'p', 'c', 'm');
    // kAudioDeviceTransportTypeBuiltIn.  The value is a four-character code
    // represented in the same big-endian form used by CoreAudio properties.
    constexpr std::uint32_t built_in_transport_type =
        four_cc('b', 'l', 't', 'n');
    constexpr std::uint32_t linear_pcm_flags = 0x0cU;
    constexpr std::uint32_t selector_control_base_class =
        four_cc('s', 'l', 'c', 't');
    constexpr std::uint32_t boolean_control_base_class =
        four_cc('t', 'o', 'g', 'l');
    constexpr std::uint32_t level_control_base_class =
        four_cc('l', 'e', 'v', 'l');
    constexpr std::uint32_t data_source_control_class =
        four_cc('d', 's', 'r', 'c');
    constexpr std::uint32_t jack_control_class = four_cc('j', 'a', 'c', 'k');
    constexpr std::uint32_t playthrough_route_control_class =
        four_cc('f', 'm', '2', 'r');
    constexpr std::uint32_t baseband_to_codec_route_control_class =
        four_cc('b', 'b', '2', 'w');
    constexpr std::uint32_t codec_to_baseband_route_control_class =
        four_cc('w', '2', 'b', 'b');
    constexpr std::uint32_t device_mute_control_class =
        four_cc('d', 'm', 'u', 't');
    constexpr std::uint32_t mute_control_class = four_cc('m', 'u', 't', 'e');
    constexpr std::uint32_t volume_control_class = four_cc('v', 'l', 'm', 'e');
    constexpr std::uint32_t output_scope = four_cc('o', 'u', 't', 'p');
    constexpr std::uint32_t input_scope = four_cc('i', 'n', 'p', 't');
    constexpr std::uint32_t playthrough_scope = four_cc('p', 't', 'r', 'u');
    constexpr std::uint32_t internal_microphone_source =
        four_cc('i', 'm', 'i', 'c');
    constexpr std::uint32_t external_microphone_source =
        four_cc('e', 'm', 'i', 'c');
    constexpr std::uint32_t line_input_source = four_cc('l', 'i', 'n', 'e');

    constexpr std::array codec_input_sources { IOAudio2SelectorItemDescription {
                                                   internal_microphone_source,
                                                   "Internal Microphone" },
        IOAudio2SelectorItemDescription {
            external_microphone_source, "External Microphone" },
        IOAudio2SelectorItemDescription { line_input_source, "Line in" } };

    constexpr std::array master_output_range { IOAudio2ControlRangeDescription {
        0xffffff8100000000ULL, 254U, 0U, 0x0000000080000000ULL } };
    constexpr std::array channel_output_range { IOAudio2ControlRangeDescription {
        0xffffffc700000000ULL, 63U, 0U, 0x0000000100000000ULL } };
    constexpr std::array input_gain_range { IOAudio2ControlRangeDescription {
        0xfffffff340000000ULL, 64U, 0U, 0x00000000c0000000ULL } };

    // Output elements identify codec endpoints, not PCM stream channels:
    // headphones, line out, receiver and speaker.  The native HAL discovers
    // each endpoint through its volume/mute controls, including the built-in
    // outputs that remain available when no external jack is connected.
    constexpr std::array<IOAudio2ControlDescription, 17> codec_controls { {
        { 3U, boolean_control_base_class, jack_control_class, output_scope, 0U,
            0U, true, { }, { } },
        { 16U, boolean_control_base_class, playthrough_route_control_class,
            playthrough_scope, 0U, 0U, false, { }, { } },
        { 17U, boolean_control_base_class,
            baseband_to_codec_route_control_class, playthrough_scope, 0U, 0U,
            false, { }, { } },
        { 18U, boolean_control_base_class,
            codec_to_baseband_route_control_class, playthrough_scope, 0U, 0U,
            false, { }, { } },
        { 6U, boolean_control_base_class, device_mute_control_class,
            output_scope, 0U, 0U, false, { }, { } },
        { 5U, boolean_control_base_class, mute_control_class, output_scope, 0U,
            0U, false, { }, { } },
        { 7U, level_control_base_class, volume_control_class, output_scope, 0U,
            254U, false, master_output_range, { } },
        { 8U, level_control_base_class, volume_control_class, output_scope, 1U,
            63U, false, channel_output_range, { } },
        { 9U, boolean_control_base_class, mute_control_class, output_scope, 1U,
            0U, false, { }, { } },
        { 10U, level_control_base_class, volume_control_class, output_scope, 2U,
            63U, false, channel_output_range, { } },
        { 11U, boolean_control_base_class, mute_control_class, output_scope, 2U,
            0U, false, { }, { } },
        { 12U, level_control_base_class, volume_control_class, output_scope, 3U,
            63U, false, channel_output_range, { } },
        { 13U, boolean_control_base_class, mute_control_class, output_scope, 3U,
            0U, false, { }, { } },
        { 14U, level_control_base_class, volume_control_class, output_scope, 4U,
            63U, false, channel_output_range, { } },
        { 15U, boolean_control_base_class, mute_control_class, output_scope, 4U,
            0U, false, { }, { } },
        { 19U, level_control_base_class, volume_control_class, input_scope, 0U,
            17U, false, input_gain_range, { } },
        { 20U, selector_control_base_class, data_source_control_class,
            input_scope, 0U, internal_microphone_source, false, { },
            codec_input_sources },
    } };

    constexpr std::array codec_streams{
    IOAudio2StreamDescription{
        .identifier = 1,
        .direction = IOAudio2StreamDirection::Output,
        .starting_channel = 1,
        .buffer_mapping_options = 1,
        .buffer_size = 4096,
        .format =
            {
                .sample_rate = 44100,
                .format_id = linear_pcm_format,
                .format_flags = linear_pcm_flags,
                .bytes_per_packet = 4,
                .frames_per_packet = 1,
                .bytes_per_frame = 4,
                .channels_per_frame = 2,
                .bits_per_channel = 16,
            },
        .available_formats = {},
    },
    IOAudio2StreamDescription{
        .identifier = 2,
        .direction = IOAudio2StreamDirection::Input,
        .starting_channel = 1,
        .buffer_mapping_options = 1,
        .buffer_size = 2048,
        .format =
            {
                .sample_rate = 44100,
                .format_id = linear_pcm_format,
                .format_flags = linear_pcm_flags,
                .bytes_per_packet = 2,
                .frames_per_packet = 1,
                .bytes_per_frame = 2,
                .channels_per_frame = 1,
                .bits_per_channel = 16,
            },
        .available_formats = {},
    },
};

    constexpr IOAudio2StreamFormatDescription baseband_media_format {
        .sample_rate = 44100,
        .format_id = linear_pcm_format,
        .format_flags = linear_pcm_flags,
        .bytes_per_packet = 4,
        .frames_per_packet = 1,
        .bytes_per_frame = 4,
        .channels_per_frame = 2,
        .bits_per_channel = 16,
    };

    constexpr IOAudio2StreamFormatDescription baseband_telephony_format {
        .sample_rate = 8000,
        .format_id = linear_pcm_format,
        .format_flags = linear_pcm_flags,
        .bytes_per_packet = 2,
        .frames_per_packet = 1,
        .bytes_per_frame = 2,
        .channels_per_frame = 1,
        .bits_per_channel = 16,
    };

    constexpr std::array baseband_formats { baseband_media_format,
        baseband_telephony_format };

    // The modem path is a distinct IOAudio2 endpoint. VirtualAudio turns this
    // endpoint into firmware-owned uplink/downlink and receiver/speaker ports.
    // It begins in the media-rate format and can negotiate the narrow-band call
    // format through the ordinary IOAudio2 stream-format selector.
    constexpr std::array baseband_streams {
        IOAudio2StreamDescription {
            .identifier = 1,
            .direction = IOAudio2StreamDirection::Output,
            .starting_channel = 1,
            .buffer_mapping_options = 1,
            .buffer_size = 4096,
            .format = baseband_media_format,
            .available_formats = baseband_formats,
        },
        IOAudio2StreamDescription {
            .identifier = 2,
            .direction = IOAudio2StreamDirection::Input,
            .starting_channel = 1,
            .buffer_mapping_options = 1,
            .buffer_size = 4096,
            .format = baseband_media_format,
            .available_formats = baseband_formats,
        },
    };

    // The iPhone 4S devices below are what its drivers publish on iOS 6.1.3,
    // read from the device's registry with IORegistryEntryCreateCFProperties
    // (see emulator-lab/docs/ios-6.1.3-audio-and-launchd.md).  Their I2S
    // frames hold two 32-bit slots: a 16-bit sample takes a slot, packed only
    // when two channels fill the frame, and a 20- or 24-bit one takes two.
    constexpr IOAudio2StreamFormatDescription i2s_format(
        std::uint32_t sample_rate, std::uint32_t channels,
        std::uint32_t bits_per_channel)
    {
        const std::uint32_t bytes_per_frame = bits_per_channel == 16U ? 4U : 8U;
        const bool packed = bits_per_channel * channels == bytes_per_frame * 8U;
        return {
            .sample_rate = sample_rate,
            .format_id = linear_pcm_format,
            .format_flags = packed ? linear_pcm_flags : 0x04U,
            .bytes_per_packet = bytes_per_frame,
            .frames_per_packet = 1,
            .bytes_per_frame = bytes_per_frame,
            .channels_per_frame = channels,
            .bits_per_channel = bits_per_channel,
        };
    }

    constexpr std::array<std::uint32_t, 9> i2s_sample_rates { 8000U, 11025U,
        12000U, 16000U, 22050U, 24000U, 32000U, 44100U, 48000U };

    // Every rate at 16, 20 and 24 bits, as the codec and Voice offer them.
    constexpr auto i2s_formats(std::uint32_t channels)
    {
        std::array<IOAudio2StreamFormatDescription,
            i2s_sample_rates.size() * 3U>
            formats { };
        std::size_t index = 0;
        for (const auto rate : i2s_sample_rates) {
            for (const auto bits : { 16U, 20U, 24U })
                formats[index++] = i2s_format(rate, channels, bits);
        }
        return formats;
    }

    // Voice is the application processor's side of a call: AppleSecondaryAudio
    // on the codec's I2S bus (IOAudio2Device "Voice"). From 6.1.3,
    // VirtualAudio opens the route only after finding its input stream.
    constexpr auto voice_formats = i2s_formats(2U);

    constexpr std::uint32_t voice_io_buffer_frame_size = 3072U;

    constexpr std::array voice_streams {
        IOAudio2StreamDescription {
            .identifier = 100,
            .direction = IOAudio2StreamDirection::Input,
            .starting_channel = 1,
            .buffer_mapping_options = 1,
            .buffer_size = voice_io_buffer_frame_size * 4U,
            .format = i2s_format(8000U, 2U, 16U),
            .available_formats = voice_formats,
        },
        IOAudio2StreamDescription {
            .identifier = 200,
            .direction = IOAudio2StreamDirection::Output,
            .starting_channel = 1,
            .buffer_mapping_options = 1,
            .buffer_size = voice_io_buffer_frame_size * 4U,
            .format = i2s_format(8000U, 2U, 16U),
            .available_formats = voice_formats,
        },
    };

    constexpr auto application_voice_source = four_cc('a', 'p', '2', 'v');
    constexpr auto dsp_voice_source = four_cc('a', 'p', '2', 'd');
    constexpr auto voice_dsp = four_cc('d', 's', 'p', '2');
    constexpr auto system_clock = four_cc('i', '2', 's', 'M');
    constexpr auto i2s_clock_domain = four_cc('I', '2', 'S', 'm');
    constexpr std::array voice_sources {
        IOAudio2SelectorItemDescription { application_voice_source, "Codec" },
        IOAudio2SelectorItemDescription {
            four_cc('b', 't', 'h', 's'), "Bluetooth" },
        IOAudio2SelectorItemDescription { dsp_voice_source, "DSP" },
    };
    constexpr std::array voice_destinations {
        IOAudio2SelectorItemDescription { voice_dsp, "DSP" },
        IOAudio2SelectorItemDescription { dsp_voice_source, "AP" },
        IOAudio2SelectorItemDescription { 0U, "Disabled" },
    };
    constexpr std::array voice_clock_sources {
        IOAudio2SelectorItemDescription { voice_dsp, "DSP" },
        IOAudio2SelectorItemDescription { system_clock, "System" },
        IOAudio2SelectorItemDescription {
            baseband_to_codec_route_control_class, "Baseband" },
    };
    constexpr std::array voice_destination_properties {
        four_cc('m', 'd', 'd', 's'), four_cc('m', 'd', 'd', '#'),
        four_cc('m', 'd', 'd', 'c'),
    };
    constexpr std::array voice_controls {
        IOAudio2ControlDescription { 300U, selector_control_base_class,
            data_source_control_class, four_cc('g', 'l', 'o', 'b'), 0U,
            application_voice_source, false, { }, voice_sources },
        IOAudio2ControlDescription { 301U, selector_control_base_class,
            four_cc('d', 'e', 's', 't'), playthrough_scope, 0U, voice_dsp,
            false, { }, voice_destinations, voice_destination_properties },
        IOAudio2ControlDescription { 302U, selector_control_base_class,
            four_cc('c', 'l', 'c', 'k'), four_cc('g', 'l', 'o', 'b'), 0U,
            voice_dsp, false, { }, voice_clock_sources },
    };

    // The codec is a Cirrus CS42L63 (AppleEmbeddedAudioDevice "Codec"): a
    // mono input and a stereo output, each at every rate in 16, 20 or 24 bits.
    constexpr std::uint32_t iphone_4s_io_buffer_frame_size = 16384U;
    constexpr auto iphone_4s_codec_input_formats = i2s_formats(1U);
    constexpr auto iphone_4s_codec_output_formats = i2s_formats(2U);

    constexpr std::array iphone_4s_codec_streams {
        IOAudio2StreamDescription {
            .identifier = 100,
            .direction = IOAudio2StreamDirection::Input,
            .starting_channel = 1,
            .buffer_mapping_options = 1,
            .buffer_size = iphone_4s_io_buffer_frame_size * 4U,
            .format = i2s_format(44100U, 1U, 16U),
            .available_formats = iphone_4s_codec_input_formats,
        },
        IOAudio2StreamDescription {
            .identifier = 200,
            .direction = IOAudio2StreamDirection::Output,
            .starting_channel = 1,
            .buffer_mapping_options = 1,
            .buffer_size = iphone_4s_io_buffer_frame_size * 4U,
            .format = i2s_format(44100U, 2U, 16U),
            .available_formats = iphone_4s_codec_output_formats,
        },
    };

    // Output elements 1 to 4 are the endpoints: two with a 2 dB and a 1 dB
    // segment, two in half-dB steps.  Element 0 is the master volume.
    constexpr std::array iphone_4s_master_volume_range {
        IOAudio2ControlRangeDescription {
            0xffffffc200000000ULL, 62U, 0U, 0x0000000100000000ULL },
    };
    constexpr std::array iphone_4s_segmented_volume_range {
        IOAudio2ControlRangeDescription {
            0xffffffb400000000ULL, 13U, 0U, 0x0000000200000000ULL },
        IOAudio2ControlRangeDescription {
            0xffffffce00000000ULL, 62U, 13U, 0x0000000100000000ULL },
    };
    constexpr std::array iphone_4s_element_3_volume_range {
        IOAudio2ControlRangeDescription {
            0xffffff9a00000000ULL, 228U, 0U, 0x0000000080000000ULL },
    };
    constexpr std::array iphone_4s_element_4_volume_range {
        IOAudio2ControlRangeDescription {
            0xffffff9b80000000ULL, 228U, 0U, 0x0000000080000000ULL },
    };
    constexpr std::array iphone_4s_input_volume_range {
        IOAudio2ControlRangeDescription {
            0xffffffa400000000ULL, 312U, 0U, 0x0000000080000000ULL },
    };
    // The read-only 'atsc' levels carry one fixed value in a stepless range.
    constexpr std::array iphone_4s_output_3_atsc_range {
        IOAudio2ControlRangeDescription {
            0x00000001b3333333ULL, 0U, 0U, 0U },
    };
    constexpr std::array iphone_4s_output_4_atsc_range {
        IOAudio2ControlRangeDescription {
            0x00000000b3333333ULL, 0U, 0U, 0U },
    };
    constexpr std::array iphone_4s_input_3_atsc_range {
        IOAudio2ControlRangeDescription {
            0xffffffff80000000ULL, 0U, 0U, 0U },
    };
    constexpr std::array iphone_4s_input_4_atsc_range {
        IOAudio2ControlRangeDescription {
            0xffffffffb3333334ULL, 0U, 0U, 0U },
    };

    constexpr auto atsc_control_class = four_cc('a', 't', 's', 'c');
    constexpr std::array iphone_4s_atsc_properties {
        four_cc('a', 't', 's', '1'), atsc_control_class,
        four_cc('a', 't', 's', '#'), four_cc('a', 't', 's', '2'),
        four_cc('a', 't', 's', '3'), four_cc('a', 't', 's', '4'),
    };
    constexpr std::array iphone_4s_device_mute_properties {
        device_mute_control_class };
    constexpr std::array iphone_4s_6wnf_properties {
        four_cc('6', 'w', 'n', 'f') };
    constexpr std::array iphone_4s_bb2w_properties {
        baseband_to_codec_route_control_class };
    constexpr std::array iphone_4s_w2bb_properties {
        codec_to_baseband_route_control_class };
    constexpr std::array iphone_4s_fm2r_properties {
        playthrough_route_control_class };

    constexpr std::array iphone_4s_codec_clock_sources {
        IOAudio2SelectorItemDescription { system_clock, "System" },
        IOAudio2SelectorItemDescription {
            baseband_to_codec_route_control_class, "Baseband" },
    };
    constexpr std::array iphone_4s_codec_output_sources {
        IOAudio2SelectorItemDescription { four_cc('c', 'o', 'd', 'c'), "Codec" },
        IOAudio2SelectorItemDescription { four_cc('v', 'o', 'i', 'c'), "Voice" },
        IOAudio2SelectorItemDescription {
            four_cc('x', 'r', 'e', 'f'), "Reference" },
    };
    constexpr std::array iphone_4s_codec_input_sources {
        IOAudio2SelectorItemDescription {
            internal_microphone_source, "Internal microphone" },
        IOAudio2SelectorItemDescription {
            four_cc('s', 'm', 'i', 'c'), "Internal secondary microphone" },
        IOAudio2SelectorItemDescription {
            external_microphone_source, "External microphone" },
    };

    constexpr auto global_scope = four_cc('g', 'l', 'o', 'b');
    constexpr std::array iphone_4s_codec_controls {
        IOAudio2ControlDescription { 300U, boolean_control_base_class,
            jack_control_class, output_scope, 0U, 0U, true, { }, { } },
        IOAudio2ControlDescription { 301U, boolean_control_base_class,
            jack_control_class, input_scope, 0U, 0U, true, { }, { } },
        IOAudio2ControlDescription { 304U, boolean_control_base_class,
            device_mute_control_class, output_scope, 0U, 0U, false, { }, { },
            iphone_4s_device_mute_properties },
        IOAudio2ControlDescription { 302U, selector_control_base_class,
            four_cc('c', 'l', 'c', 'k'), global_scope, 0U, system_clock, false,
            { }, iphone_4s_codec_clock_sources },
        IOAudio2ControlDescription { 305U, level_control_base_class,
            volume_control_class, output_scope, 0U, 62U, false,
            iphone_4s_master_volume_range, { } },
        IOAudio2ControlDescription { 306U, level_control_base_class,
            volume_control_class, output_scope, 1U, 0U, false,
            iphone_4s_segmented_volume_range, { } },
        IOAudio2ControlDescription { 307U, boolean_control_base_class,
            mute_control_class, output_scope, 1U, 1U, false, { }, { } },
        IOAudio2ControlDescription { 308U, level_control_base_class,
            volume_control_class, output_scope, 2U, 63U, false,
            iphone_4s_segmented_volume_range, { } },
        IOAudio2ControlDescription { 309U, boolean_control_base_class,
            mute_control_class, output_scope, 2U, 1U, false, { }, { } },
        IOAudio2ControlDescription { 311U, level_control_base_class,
            volume_control_class, output_scope, 3U, 0U, false,
            iphone_4s_element_3_volume_range, { } },
        IOAudio2ControlDescription { 312U, boolean_control_base_class,
            mute_control_class, output_scope, 3U, 1U, false, { }, { } },
        IOAudio2ControlDescription { 313U, level_control_base_class,
            volume_control_class, output_scope, 4U, 201U, false,
            iphone_4s_element_4_volume_range, { } },
        IOAudio2ControlDescription { 314U, boolean_control_base_class,
            mute_control_class, output_scope, 4U, 0U, false, { }, { } },
        IOAudio2ControlDescription { 315U, selector_control_base_class,
            data_source_control_class, output_scope, 4U,
            four_cc('c', 'o', 'd', 'c'), false, { },
            iphone_4s_codec_output_sources },
        IOAudio2ControlDescription { 318U, level_control_base_class,
            atsc_control_class, output_scope, 3U, 0U, true,
            iphone_4s_output_3_atsc_range, { }, iphone_4s_atsc_properties },
        IOAudio2ControlDescription { 319U, level_control_base_class,
            atsc_control_class, output_scope, 4U, 0U, true,
            iphone_4s_output_4_atsc_range, { }, iphone_4s_atsc_properties },
        IOAudio2ControlDescription { 349U, level_control_base_class,
            volume_control_class, input_scope, 0U, 248U, false,
            iphone_4s_input_volume_range, { } },
        IOAudio2ControlDescription { 348U, boolean_control_base_class,
            mute_control_class, input_scope, 0U, 0U, false, { }, { } },
        IOAudio2ControlDescription { 350U, selector_control_base_class,
            data_source_control_class, input_scope, 0U, 0U, false, { },
            iphone_4s_codec_input_sources, { }, true },
        IOAudio2ControlDescription { 373U, boolean_control_base_class,
            four_cc('6', 'w', 'n', 'f'), input_scope, 0U, 1U, false, { }, { },
            iphone_4s_6wnf_properties },
        IOAudio2ControlDescription { 353U, level_control_base_class,
            atsc_control_class, input_scope, 3U, 0U, true,
            iphone_4s_input_3_atsc_range, { }, iphone_4s_atsc_properties },
        IOAudio2ControlDescription { 354U, level_control_base_class,
            atsc_control_class, input_scope, 4U, 0U, true,
            iphone_4s_input_4_atsc_range, { }, iphone_4s_atsc_properties },
        IOAudio2ControlDescription { 368U, boolean_control_base_class,
            baseband_to_codec_route_control_class, playthrough_scope, 0U, 0U,
            false, { }, { }, iphone_4s_bb2w_properties },
        IOAudio2ControlDescription { 369U, boolean_control_base_class,
            codec_to_baseband_route_control_class, playthrough_scope, 0U, 0U,
            false, { }, { }, iphone_4s_w2bb_properties },
        IOAudio2ControlDescription { 367U, boolean_control_base_class,
            playthrough_route_control_class, playthrough_scope, 0U, 0U, false,
            { }, { }, iphone_4s_fm2r_properties },
    };

    // The modem's audio (AppleBasebandAudio "Baseband"): 44.1 kHz stereo,
    // with mono at 8 kHz and mono or stereo at 32, 44.1 and 48 kHz.
    constexpr std::array iphone_4s_baseband_formats {
        i2s_format(8000U, 1U, 16U),
        i2s_format(32000U, 2U, 16U),
        i2s_format(32000U, 1U, 16U),
        i2s_format(44100U, 2U, 16U),
        i2s_format(44100U, 1U, 16U),
        i2s_format(48000U, 2U, 16U),
        i2s_format(48000U, 1U, 16U),
    };

    constexpr std::array iphone_4s_baseband_streams {
        IOAudio2StreamDescription {
            .identifier = 100,
            .direction = IOAudio2StreamDirection::Input,
            .starting_channel = 1,
            .buffer_mapping_options = 1,
            .buffer_size = iphone_4s_io_buffer_frame_size * 4U,
            .format = i2s_format(44100U, 2U, 16U),
            .available_formats = iphone_4s_baseband_formats,
        },
        IOAudio2StreamDescription {
            .identifier = 200,
            .direction = IOAudio2StreamDirection::Output,
            .starting_channel = 1,
            .buffer_mapping_options = 1,
            .buffer_size = iphone_4s_io_buffer_frame_size * 4U,
            .format = i2s_format(44100U, 2U, 16U),
            .available_formats = iphone_4s_baseband_formats,
        },
    };

    // The call path between the modem and the DSP (AppleSecondaryAudio
    // "Baseband Voice"): mono at 8 or 16 kHz in 16, 20 or 24 bits.
    constexpr std::array iphone_4s_baseband_voice_formats {
        i2s_format(8000U, 1U, 16U),
        i2s_format(8000U, 1U, 20U),
        i2s_format(8000U, 1U, 24U),
        i2s_format(16000U, 1U, 16U),
        i2s_format(16000U, 1U, 20U),
        i2s_format(16000U, 1U, 24U),
    };

    constexpr std::array iphone_4s_baseband_voice_streams {
        IOAudio2StreamDescription {
            .identifier = 100,
            .direction = IOAudio2StreamDirection::Input,
            .starting_channel = 1,
            .buffer_mapping_options = 1,
            .buffer_size = voice_io_buffer_frame_size * 4U,
            .format = i2s_format(8000U, 1U, 16U),
            .available_formats = iphone_4s_baseband_voice_formats,
        },
        IOAudio2StreamDescription {
            .identifier = 200,
            .direction = IOAudio2StreamDirection::Output,
            .starting_channel = 1,
            .buffer_mapping_options = 1,
            .buffer_size = voice_io_buffer_frame_size * 4U,
            .format = i2s_format(8000U, 1U, 16U),
            .available_formats = iphone_4s_baseband_voice_formats,
        },
    };

    constexpr auto baseband_voice_source = four_cc('a', 'p', '2', 'b');
    constexpr std::array iphone_4s_baseband_voice_sources {
        IOAudio2SelectorItemDescription { baseband_voice_source, "Baseband" },
        IOAudio2SelectorItemDescription { dsp_voice_source, "DSP" },
    };
    constexpr std::array iphone_4s_baseband_voice_clock_sources {
        IOAudio2SelectorItemDescription {
            baseband_to_codec_route_control_class, "Baseband" },
        IOAudio2SelectorItemDescription { system_clock, "System" },
    };
    constexpr std::array iphone_4s_baseband_voice_controls {
        IOAudio2ControlDescription { 300U, selector_control_base_class,
            data_source_control_class, global_scope, 0U, baseband_voice_source,
            false, { }, iphone_4s_baseband_voice_sources },
        IOAudio2ControlDescription { 301U, selector_control_base_class,
            four_cc('d', 'e', 's', 't'), playthrough_scope, 0U, voice_dsp,
            false, { }, voice_destinations, voice_destination_properties },
        IOAudio2ControlDescription { 302U, selector_control_base_class,
            four_cc('c', 'l', 'c', 'k'), global_scope, 0U,
            baseband_to_codec_route_control_class, false, { },
            iphone_4s_baseband_voice_clock_sources },
    };

    // The voice DSP (HighlandParkAudioDevice "HighlandPark", no name): mono
    // 16-bit at every rate, with its processing modes as selectors.
    constexpr auto iphone_4s_highland_park_formats = [] {
        std::array<IOAudio2StreamFormatDescription, i2s_sample_rates.size()>
            formats { };
        for (std::size_t index = 0; index < formats.size(); ++index)
            formats[index] = i2s_format(i2s_sample_rates[index], 1U, 16U);
        return formats;
    }();

    constexpr std::array iphone_4s_highland_park_streams {
        IOAudio2StreamDescription {
            .identifier = 100,
            .direction = IOAudio2StreamDirection::Input,
            .starting_channel = 1,
            .buffer_mapping_options = 1,
            .buffer_size = iphone_4s_io_buffer_frame_size * 4U,
            .format = i2s_format(44100U, 1U, 16U),
            .available_formats = iphone_4s_highland_park_formats,
        },
        IOAudio2StreamDescription {
            .identifier = 200,
            .direction = IOAudio2StreamDirection::Output,
            .starting_channel = 1,
            .buffer_mapping_options = 1,
            .buffer_size = iphone_4s_io_buffer_frame_size * 4U,
            .format = i2s_format(44100U, 1U, 16U),
            .available_formats = iphone_4s_highland_park_formats,
        },
    };

    constexpr std::array iphone_4s_highland_park_fine_range {
        IOAudio2ControlRangeDescription {
            0xffffffa60000021cULL, 1200U, 0U, 0x0000000019999999ULL },
    };
    constexpr std::array iphone_4s_highland_park_input_fine_range {
        IOAudio2ControlRangeDescription {
            0xffffffa60000021cULL, 1800U, 0U, 0x0000000019999999ULL },
    };
    constexpr std::array iphone_4s_highland_park_coarse_range {
        IOAudio2ControlRangeDescription {
            0xffffffa600000000ULL, 180U, 0U, 0x0000000100000000ULL },
    };

    constexpr std::array iphone_4s_highland_park_modes {
        IOAudio2SelectorItemDescription {
            four_cc('u', 'n', 'd', 'f'), "Undefined mode" },
        IOAudio2SelectorItemDescription {
            four_cc('n', 'd', 's', 'p'), "No DSP mode" },
        IOAudio2SelectorItemDescription {
            four_cc('i', 'm', 'c', 'r'), "Internal Mic - Receiver" },
        IOAudio2SelectorItemDescription {
            four_cc('i', 'm', 'c', 's'), "Internal Mic - Speaker" },
        IOAudio2SelectorItemDescription { four_cc('i', 'm', 'd', 'h'),
            "Internal Mic - default wired Headset" },
        IOAudio2SelectorItemDescription {
            four_cc('w', 'm', 'd', 'h'), "Wired Mic - default Headset" },
        IOAudio2SelectorItemDescription {
            four_cc('w', 'm', 'a', 'h'), "Wired Mic - A36 Headset" },
        IOAudio2SelectorItemDescription {
            four_cc('b', 'm', 'b', 'h'), "BT Mic - BT Headset" },
        IOAudio2SelectorItemDescription {
            four_cc('b', 'n', 'o', 'd'), "BT Mic - BT Headset - No DSP" },
        IOAudio2SelectorItemDescription { four_cc('t', 't', 'y', 'c'), "TTYCall" },
        IOAudio2SelectorItemDescription { four_cc('b', 'b', 'a', 'p'), "BB to AP" },
        IOAudio2SelectorItemDescription { four_cc('f', 'l', 'u', 'e'), "Fluence" },
    };
    constexpr std::array iphone_4s_highland_park_input_sets {
        IOAudio2SelectorItemDescription { 0U, "AIS0" },
        IOAudio2SelectorItemDescription { 1U, "AIS1" },
        IOAudio2SelectorItemDescription { 2U, "AIS2" },
        IOAudio2SelectorItemDescription { 3U, "AIS3" },
        IOAudio2SelectorItemDescription { 4U, "AIS4" },
    };
    constexpr std::array iphone_4s_highland_park_networks {
        IOAudio2SelectorItemDescription { four_cc('g', 's', 'm', ' '), "GSM" },
        IOAudio2SelectorItemDescription { four_cc('c', 'd', 'm', 'a'), "CDMA" },
        IOAudio2SelectorItemDescription { four_cc('w', 'g', 's', 'm'), "GSM_WB" },
    };
    constexpr std::array iphone_4s_highland_park_mix_modes {
        IOAudio2SelectorItemDescription { four_cc('i', 'n', 't', ' '), "Internal" },
        IOAudio2SelectorItemDescription { four_cc('e', 'x', 't', ' '), "External" },
        IOAudio2SelectorItemDescription {
            four_cc('i', 'n', 'u', 'l'), "Internal with UL mixing" },
        IOAudio2SelectorItemDescription {
            four_cc('i', 'n', 'e', 'c'), "Internal with Echo ref" },
        IOAudio2SelectorItemDescription { four_cc('l', 'o', 'o', 'p'), "Loopback" },
    };
    constexpr std::array iphone_4s_highland_park_downlink_eq {
        IOAudio2SelectorItemDescription { 1U, "DL EQ index 1" },
        IOAudio2SelectorItemDescription { 2U, "DL EQ index 2" },
        IOAudio2SelectorItemDescription { 3U, "DL EQ index 3" },
        IOAudio2SelectorItemDescription { 4U, "DL EQ index 4" },
        IOAudio2SelectorItemDescription { 5U, "DL EQ index 5" },
    };
    constexpr std::array iphone_4s_highland_park_uplink_eq {
        IOAudio2SelectorItemDescription { 1U, "UL EQ index 1" },
        IOAudio2SelectorItemDescription { 2U, "UL EQ index 2" },
        IOAudio2SelectorItemDescription { 3U, "UL EQ index 3" },
        IOAudio2SelectorItemDescription { 4U, "UL EQ index 4" },
        IOAudio2SelectorItemDescription { 5U, "UL EQ index 5" },
    };
    constexpr std::array iphone_4s_highland_park_input_set_properties {
        four_cc('n', 's', 'l', '0'), four_cc('n', 's', 'l', '1'),
        four_cc('n', 's', 'l', '2'),
    };
    constexpr std::array iphone_4s_highland_park_power_properties {
        four_cc('p', 'w', 'r', '1') };
    constexpr std::array iphone_4s_highland_park_network_properties {
        four_cc('n', 't', 'm', '0'), four_cc('n', 't', 'm', '1'),
        four_cc('n', 't', 'm', '2'),
    };
    constexpr std::array iphone_4s_highland_park_mix_properties {
        four_cc('m', 'i', 'x', '0'), four_cc('m', 'i', 'x', '1'),
        four_cc('m', 'i', 'x', '2'),
    };
    constexpr std::array iphone_4s_highland_park_downlink_eq_properties {
        four_cc('b', 't', 'e', 'd'), four_cc('b', 't', 'e', '1'),
        four_cc('b', 't', 'e', '2'),
    };
    constexpr std::array iphone_4s_highland_park_uplink_eq_properties {
        four_cc('b', 't', 'e', 'u'), four_cc('b', 't', 'e', '3'),
        four_cc('b', 't', 'e', '4'),
    };
    constexpr std::array iphone_4s_highland_park_agc_properties {
        four_cc('a', 'g', 'c', '0') };

    constexpr std::array iphone_4s_highland_park_controls {
        IOAudio2ControlDescription { 17U, boolean_control_base_class,
            mute_control_class, output_scope, 0U, 0U, false, { }, { } },
        IOAudio2ControlDescription { 12U, level_control_base_class,
            volume_control_class, output_scope, 0U, 0U, false,
            iphone_4s_highland_park_fine_range, { } },
        IOAudio2ControlDescription { 16U, boolean_control_base_class,
            mute_control_class, output_scope, 1U, 0U, false, { }, { } },
        IOAudio2ControlDescription { 11U, level_control_base_class,
            volume_control_class, output_scope, 1U, 0U, false,
            iphone_4s_highland_park_coarse_range, { } },
        IOAudio2ControlDescription { 18U, boolean_control_base_class,
            mute_control_class, output_scope, 2U, 0U, false, { }, { } },
        IOAudio2ControlDescription { 13U, level_control_base_class,
            volume_control_class, output_scope, 2U, 0U, false,
            iphone_4s_highland_park_coarse_range, { } },
        IOAudio2ControlDescription { 20U, boolean_control_base_class,
            mute_control_class, input_scope, 0U, 0U, false, { }, { } },
        IOAudio2ControlDescription { 15U, level_control_base_class,
            volume_control_class, input_scope, 0U, 0U, false,
            iphone_4s_highland_park_input_fine_range, { } },
        IOAudio2ControlDescription { 19U, boolean_control_base_class,
            mute_control_class, input_scope, 1U, 0U, false, { }, { } },
        IOAudio2ControlDescription { 14U, level_control_base_class,
            volume_control_class, input_scope, 1U, 0U, false,
            iphone_4s_highland_park_coarse_range, { } },
        IOAudio2ControlDescription { 10U, selector_control_base_class,
            data_source_control_class, global_scope, 0U,
            four_cc('u', 'n', 'd', 'f'), false, { },
            iphone_4s_highland_park_modes },
        IOAudio2ControlDescription { 21U, selector_control_base_class,
            four_cc('n', 's', 'l', '0'), global_scope, 0U, 0U, false, { },
            iphone_4s_highland_park_input_sets,
            iphone_4s_highland_park_input_set_properties },
        IOAudio2ControlDescription { 22U, boolean_control_base_class,
            four_cc('p', 'w', 'r', '0'), global_scope, 0U, 0U, false, { }, { },
            iphone_4s_highland_park_power_properties },
        IOAudio2ControlDescription { 23U, selector_control_base_class,
            four_cc('n', 't', 'w', 'k'), global_scope, 0U, 0U, false, { },
            iphone_4s_highland_park_networks,
            iphone_4s_highland_park_network_properties },
        IOAudio2ControlDescription { 24U, selector_control_base_class,
            four_cc('m', 'i', 'x', 'm'), global_scope, 0U, 0U, false, { },
            iphone_4s_highland_park_mix_modes,
            iphone_4s_highland_park_mix_properties },
        IOAudio2ControlDescription { 25U, selector_control_base_class,
            four_cc('b', 't', 'e', 'd'), global_scope, 0U, 0U, false, { },
            iphone_4s_highland_park_downlink_eq,
            iphone_4s_highland_park_downlink_eq_properties },
        IOAudio2ControlDescription { 26U, selector_control_base_class,
            four_cc('b', 't', 'e', 'u'), global_scope, 0U, 0U, false, { },
            iphone_4s_highland_park_uplink_eq,
            iphone_4s_highland_park_uplink_eq_properties },
        IOAudio2ControlDescription { 27U, boolean_control_base_class,
            four_cc('a', 'g', 'c', '0'), global_scope, 0U, 0U, false, { }, { },
            iphone_4s_highland_park_agc_properties },
    };

    // The dock's digital audio out (AppleUSBMike "USB Audio Output"): one
    // stereo 16-bit output at every rate, non-mixable.
    constexpr std::uint32_t iphone_4s_usb_io_buffer_frame_size = 14112U;
    constexpr IOAudio2StreamFormatDescription usb_output_format(
        std::uint32_t sample_rate)
    {
        return {
            .sample_rate = sample_rate,
            .format_id = linear_pcm_format,
            .format_flags = 0x4cU,
            .bytes_per_packet = 4,
            .frames_per_packet = 1,
            .bytes_per_frame = 4,
            .channels_per_frame = 2,
            .bits_per_channel = 16,
        };
    }
    constexpr auto iphone_4s_usb_formats = [] {
        std::array<IOAudio2StreamFormatDescription, i2s_sample_rates.size()>
            formats { };
        for (std::size_t index = 0; index < formats.size(); ++index)
            formats[index] = usb_output_format(i2s_sample_rates[index]);
        return formats;
    }();
    constexpr std::array iphone_4s_usb_streams {
        IOAudio2StreamDescription {
            .identifier = 1,
            .direction = IOAudio2StreamDirection::Output,
            .starting_channel = 1,
            .buffer_mapping_options = 1,
            .buffer_size = iphone_4s_usb_io_buffer_frame_size * 4U,
            .format = usb_output_format(44100U),
            .available_formats = iphone_4s_usb_formats,
        },
    };

    constexpr std::array device_catalog {
        IOAudio2DeviceDescription {
            .name = "Built-in Audio",
            .manufacturer = "Apple Computer, Inc.",
            .uid = "Codec",
            .transport_type = built_in_transport_type,
            .io_buffer_frame_size = 1024,
            .streams = codec_streams,
            .controls = codec_controls,
        },
        IOAudio2DeviceDescription {
            .name = "Baseband",
            .manufacturer = "Apple Computer, Inc.",
            .uid = "Baseband",
            .transport_type = built_in_transport_type,
            .io_buffer_frame_size = 1024,
            .streams = baseband_streams,
            .controls = { },
        },
    };

    constexpr std::array iphone_4s_device_catalog {
        IOAudio2DeviceDescription {
            .name = "CS42L63",
            .manufacturer = "Apple Inc.",
            .uid = "Codec",
            .transport_type = 0U,
            .io_buffer_frame_size = iphone_4s_io_buffer_frame_size,
            .streams = iphone_4s_codec_streams,
            .controls = iphone_4s_codec_controls,
            .input_latency = 37,
            .output_latency = 34,
            .input_safety_offset = 96,
            .output_safety_offset = 96,
            .clock_domain = i2s_clock_domain,
        },
        IOAudio2DeviceDescription {
            .name = "Baseband",
            .manufacturer = "Apple Inc.",
            .uid = "Baseband",
            .transport_type = 0U,
            .io_buffer_frame_size = iphone_4s_io_buffer_frame_size,
            .streams = iphone_4s_baseband_streams,
            .controls = { },
            .input_latency = 766,
            .output_latency = 766,
            .input_safety_offset = 96,
            .output_safety_offset = 96,
            .clock_domain = i2s_clock_domain,
        },
        IOAudio2DeviceDescription {
            .name = "Voice",
            .manufacturer = "Apple Inc.",
            .uid = "Voice",
            .transport_type = 0U,
            .io_buffer_frame_size = voice_io_buffer_frame_size,
            .streams = voice_streams,
            .controls = voice_controls,
            .input_latency = 12,
            .output_latency = 13,
            .input_safety_offset = 48,
            .output_safety_offset = 48,
            .clock_domain = i2s_clock_domain,
        },
        IOAudio2DeviceDescription {
            .name = "Baseband Voice",
            .manufacturer = "Apple Inc.",
            .uid = "Baseband Voice",
            .transport_type = 0U,
            .io_buffer_frame_size = voice_io_buffer_frame_size,
            .streams = iphone_4s_baseband_voice_streams,
            .controls = iphone_4s_baseband_voice_controls,
            .input_latency = 4,
            .output_latency = 4,
            .input_safety_offset = 48,
            .output_safety_offset = 48,
            .clock_domain = 0U,
        },
        IOAudio2DeviceDescription {
            .name = std::nullopt,
            .manufacturer = "Apple Inc.",
            .uid = "HighlandPark",
            .transport_type = 0U,
            .io_buffer_frame_size = iphone_4s_io_buffer_frame_size,
            .streams = iphone_4s_highland_park_streams,
            .controls = iphone_4s_highland_park_controls,
            .input_latency = 23,
            .output_latency = 23,
            .input_safety_offset = 96,
            .output_safety_offset = 96,
            .clock_domain = i2s_clock_domain,
        },
        IOAudio2DeviceDescription {
            .name = "USB Audio Output",
            .manufacturer = "Apple Computer, Inc.",
            .uid = "USB Audio Output",
            .transport_type = four_cc('u', 's', 'b', ' '),
            .io_buffer_frame_size = iphone_4s_usb_io_buffer_frame_size,
            .streams = iphone_4s_usb_streams,
            .controls = { },
            .input_latency = 0,
            .output_latency = 0,
            .input_safety_offset = 0,
            .output_safety_offset = 2816,
        },
    };

    std::span<const IOAudio2DeviceDescription> catalog_for(
        AudioHardwareProfile profile)
    {
        if (profile == AudioHardwareProfile::CodecBasebandVoiceRouting)
            return iphone_4s_device_catalog;
        return device_catalog;
    }

} // namespace

std::span<const IOAudio2DeviceDescription> IOAudio2DeviceCatalog::devices(
    AudioHardwareProfile profile)
{
    return catalog_for(profile);
}

const IOAudio2DeviceDescription* IOAudio2DeviceCatalog::find(
    std::string_view uid, AudioHardwareProfile profile)
{
    const auto devices = catalog_for(profile);
    const auto device = std::ranges::find_if(devices,
        [uid](const auto& candidate) { return candidate.uid == uid; });
    return device == devices.end() ? nullptr : &*device;
}

} // namespace shade::kernel_iokit::audio
