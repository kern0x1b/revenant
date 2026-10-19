package("gn")
    set_kind("binary")
    set_homepage("https://gn.googlesource.com/gn")
    set_description("GN, the meta-build system that generates Ninja files, as a host tool for a package whose upstream builds with GN (Matter, and whatever builds with CMake and Ninja together)")
    set_license("BSD-3-Clause")

    -- The same binaries xmake-repo ships, pinned here so a build of a GN-driven upstream resolves the tool from this
    -- repository rather than from whatever happens to be on the host's PATH.
    if is_host("macosx") then
        if os.arch() == "arm64" then
            add_urls("https://github.com/xmake-mirror/gn-releases/releases/download/v$(version)/gn-mac-arm64.zip")
            add_versions("20211117", "5954adcaaf6ed69ab4c5270897ea389ce94d0584c709040257428f8604400211")
        else
            add_urls("https://github.com/xmake-mirror/gn-releases/releases/download/v$(version)/gn-mac-amd64.zip")
            add_versions("20211117", "025d9d60da03e080603a78c94a885d5c864c859248a877b2684d808aa5987c86")
        end
    elseif is_host("linux") then
        if os.arch() == "x86_64" then
            add_urls("https://github.com/xmake-mirror/gn-releases/releases/download/v$(version)/gn-linux-amd64.zip")
            add_versions("20211117", "6cc2da268a8402c0ac4f933fb06e8ac656a2450e5a4b645586b0b6a8b3e2944f")
        end
    elseif is_host("windows") then
        if os.arch() == "x64" then
            add_urls("https://github.com/xmake-mirror/gn-releases/releases/download/v$(version)/gn-windows-amd64.zip")
            add_versions("20211117", "517cdbfc1cbcc349d92781cd88ea34fb294b2a7f7b24c10678582eee587ee5b6")
        end
    end

    on_install("@macosx", "@linux", "@windows", function (package)
        os.cp("gn*", package:installdir("bin"))
    end)

    on_test(function (package)
        os.vrun("gn --version")
    end)
