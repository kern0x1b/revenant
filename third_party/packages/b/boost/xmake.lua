package("boost")
    set_kind("library", {headeronly = true})
    set_homepage("https://www.boost.org")
    set_description("Boost, its headers only: what dynarmic and the emulator include of it, from the release archive")
    set_license("BSL-1.0")

    add_urls("https://archives.boost.io/release/1.81.0/source/boost_1_81_0.tar.bz2")
    add_versions("1.81.0", "71feeed900fbccca04a3b4f2f84a7c217186f28a940ed8b7ed4725986baf99fa")

    on_install(function (package)
        os.cp("boost", package:installdir("include"))
        os.cp("LICENSE_1_0.txt", package:installdir("licenses") .. "/")
    end)

    on_test(function (package)
        assert(package:has_cxxincludes("boost/version.hpp"))
    end)
