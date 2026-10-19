// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Index firmware launchd job declarations and their advertised Mach
// services.

#include "device_state/launchd_job_catalog.hpp"

#include <array>
#include <cstdint>
#include <cstdlib>
#include <fstream>
#include <iterator>
#include <system_error>
#include <vector>

#if defined(SHADE_HAS_LIBPLIST)
#include <plist/plist.h>
#endif

namespace shade {
namespace {

#if defined(SHADE_HAS_LIBPLIST)

    class PlistOwner {
    public:
        explicit PlistOwner(plist_t node = nullptr)
            : node_ { node }
        {
        }
        ~PlistOwner()
        {
            if (node_ != nullptr)
                plist_free(node_);
        }
        PlistOwner(const PlistOwner&) = delete;
        PlistOwner& operator=(const PlistOwner&) = delete;

        [[nodiscard]] plist_t get() const { return node_; }

    private:
        plist_t node_ { };
    };

    std::vector<char> read_file(const std::filesystem::path& path)
    {
        std::ifstream input { path, std::ios::binary };
        if (!input)
            return { };
        return { std::istreambuf_iterator<char> { input },
            std::istreambuf_iterator<char> { } };
    }

    std::string plist_string(plist_t node)
    {
        if (node == nullptr || plist_get_node_type(node) != PLIST_STRING)
            return { };
        std::uint64_t length { };
        const auto* value = plist_get_string_ptr(node, &length);
        return value == nullptr
                   ? std::string { }
                   : std::string { value, static_cast<std::size_t>(length) };
    }

    std::string job_executable(plist_t job)
    {
        auto executable = plist_string(plist_dict_get_item(job, "Program"));
        if (!executable.empty())
            return executable;
        const auto arguments = plist_dict_get_item(job, "ProgramArguments");
        if (arguments == nullptr ||
            plist_get_node_type(arguments) != PLIST_ARRAY ||
            plist_array_get_size(arguments) == 0U) {
            return { };
        }
        return plist_string(plist_array_get_item(arguments, 0U));
    }

#endif

} // namespace

LaunchdJobCatalog LaunchdJobCatalog::load(const std::filesystem::path& rootfs)
{
    LaunchdJobCatalog catalog;
#if defined(SHADE_HAS_LIBPLIST)
    constexpr std::array<std::string_view, 3> directories {
        "System/Library/LaunchDaemons", "Library/LaunchDaemons",
        "System/Library/LaunchAgents"
    };
    for (const auto directory : directories) {
        std::error_code error;
        const auto path = rootfs / directory;
        for (std::filesystem::directory_iterator entries { path,
                 std::filesystem::directory_options::skip_permission_denied,
                 error };
            !error && entries != std::filesystem::directory_iterator { };
            entries.increment(error)) {
            if (entries->path().extension() == ".plist")
                catalog.add_job(entries->path());
        }
    }
#else
    static_cast<void>(rootfs);
#endif
    return catalog;
}

bool LaunchdJobCatalog::executable_provides_service(
    std::string_view executable, std::string_view service) const
{
    const auto job = services_by_executable_.find(executable);
    return job != services_by_executable_.end() &&
           job->second.contains(service);
}

#if defined(SHADE_HAS_LIBPLIST)
void LaunchdJobCatalog::add_job(const std::filesystem::path& path)
{
    const auto bytes = read_file(path);
    if (bytes.empty())
        return;
    plist_t parsed = nullptr;
    plist_format_t format = PLIST_FORMAT_NONE;
    if (plist_from_memory(bytes.data(),
            static_cast<std::uint32_t>(bytes.size()), &parsed,
            &format) != PLIST_ERR_SUCCESS ||
        parsed == nullptr) {
        return;
    }
    const PlistOwner owner { parsed };
    if (plist_get_node_type(parsed) != PLIST_DICT)
        return;
    const auto executable = job_executable(parsed);
    const auto services = plist_dict_get_item(parsed, "MachServices");
    if (executable.empty() || services == nullptr ||
        plist_get_node_type(services) != PLIST_DICT) {
        return;
    }
    plist_dict_iter iterator = nullptr;
    plist_dict_new_iter(services, &iterator);
    if (iterator == nullptr)
        return;
    auto& provided = services_by_executable_[executable];
    for (;;) {
        char* key = nullptr;
        plist_t value = nullptr;
        plist_dict_next_item(services, iterator, &key, &value);
        static_cast<void>(value);
        if (key == nullptr)
            break;
        provided.emplace(key);
        free(key);
    }
    free(iterator);
}
#endif

} // namespace shade
