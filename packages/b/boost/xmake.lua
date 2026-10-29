package("boost")
    set_kind("library", {headeronly = true})
    set_homepage("https://www.boost.org")
    set_description("Boost, its headers only: what dynarmic and the emulator include of it, from the release archive, and what React Native 0.86 includes of it, the 1.84.0 subset React Native ships (boost-for-react-native at its v1.84.0 tag)")
    set_license("BSL-1.0")

    add_urls("https://archives.boost.io/release/1.81.0/source/boost_1_81_0.tar.bz2")
    add_urls("https://github.com/react-native-community/boost-for-react-native.git", {alias = "react-native"})
    add_versions("1.81.0", "71feeed900fbccca04a3b4f2f84a7c217186f28a940ed8b7ed4725986baf99fa")
    add_versions("react-native:1.84.0", "59ed9e589e222fb6d54b3e0a81d510190801b1d9")

    on_load("iphoneos", function (package)
        package:add("deps", "revenant@libcxx", {alias = "libcxx"})
    end)

    on_install(function (package)
        os.cp("boost", package:installdir("include"))
        os.cp("LICENSE_1_0.txt", package:installdir("licenses") .. "/")
    end)

    on_test(function (package)
        assert(package:has_cxxincludes("boost/version.hpp"))
        if not package:is_plat("iphoneos") then
            return
        end
        local version = package:version()
        local probe = import("@addon.revenant.apple.probe", {anonymous = true})
        local ok, output = probe.check(package, {source = string.format([[
#include <boost/version.hpp>
#include <boost/container/vector.hpp>
#include <boost/function.hpp>
int main() {
    boost::container::vector<int> values;
    values.push_back(1);
    boost::function<int(int)> twice = [](int value) { return 2 * value; };
    return BOOST_VERSION == %d && twice(values[0]) == 2 ? 0 : 1;
}
]], version:major() * 100000 + version:minor() * 100 + version:patch()), deps = {"libcxx"}, flags = {"-std=c++20"}, link = true})
        assert(ok, "boost " .. package:version_str() .. " does not compile and link against armv7 libc++: " .. output)
    end)
