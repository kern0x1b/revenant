package("opencv")
    set_homepage("https://opencv.org")
    set_description("OpenCV 3.4.20, the visual-inertial odometry ARKit's tracker is built on: ORB features from features2d, and the essential-matrix, RANSAC and pose-recovery calls of calib3d, as a static library for the image that links it in")
    set_license("BSD-3-Clause")
    set_policy("package.strict_compatibility", true)

    -- 3.4.x, not 4.x: 3.4 is the line that shipped an official armv7 iOS framework build
    -- (platforms/ios/build_framework.py, in this very tree), so armv7 at a 6.x deployment is a path
    -- upstream walked, and 4.x's arm64-and-up assumptions never were. The tag is pinned and the
    -- archive is checked, so a tree that is not this one cannot be built in its place.
    add_urls("https://codeload.github.com/opencv/opencv/tar.gz/refs/tags/3.4.20.tar.gz")
    add_versions("3.4.20", "b9eda448a08ba7b10bfd5bd45697056569ebdf7a02070947e1c1f3e8e69280cd")
    add_links("opencv_core", "opencv_imgproc", "opencv_features2d", "opencv_flann", "opencv_calib3d")

    add_configs("recipe", {description = "The digest of this recipe, so a changed flag is a different library.", default = hash.strhash128(hash.sha256(path.join(os.scriptdir(), "xmake.lua"))), type = "string", readonly = true})

    -- Five modules and nothing else: core and imgproc are what the tracker reads frames with,
    -- flann is what features2d indexes descriptors with, features2d is ORB, and calib3d is
    -- findEssentialMat, recoverPose and solvePnPRansac. No apps, no tests, no IPP, no OpenCL, no
    -- codecs: every one of those is either a target this image cannot use or a dependency this tree
    -- does not carry, and each would have to be turned off explicitly.
    local MODULES = "core,imgproc,features2d,flann,calib3d"

    -- Hidden, so the engine is never API of the image it is linked into: libARKitBackports.dylib
    -- exports what ARKit does, and nothing a second copy of OpenCV in the process could bind to.
    -- No exceptions and no RTTI: these modules use neither for what the tracker calls, and without
    -- them this needs of the C++ runtime only operator delete and __cxa_pure_virtual, which every
    -- release from 5.0 exports. The release's own libstdc++ is not used at all: the tree carries
    -- libc++ (packages/l/libcxx), and a C++ runtime of the device's own would be a second one.
    local FLAGS = {"-Os", "-fvisibility=hidden", "-fvisibility-inlines-hidden",
                   "-fno-exceptions", "-fno-rtti", "-std=c++11"}

    on_install("iphoneos", function (package)
        local toolchain = assert(package:toolchains(), "opencv is built with the apple-ios toolchain")[1]
        toolchain:load()
        local target = {"-target", package:arch() .. "-apple-ios",
                        "-miphoneos-version-min=" .. toolchain:config("deployment"),
                        "-isysroot", toolchain:config("sdkdir")}

        local build = path.join(os.curdir(), "build")
        os.mkdir(build)
        local configure = {"cmake", "-G", "Unix Makefiles", "-DCMAKE_BUILD_TYPE=Release",
                           "-DBUILD_LIST=" .. MODULES,
                           "-DBUILD_SHARED_LIBS=OFF", "-DBUILD_opencv_apps=OFF",
                           "-DBUILD_TESTS=OFF", "-DBUILD_PERF_TESTS=OFF", "-DBUILD_EXAMPLES=OFF",
                           "-DBUILD_DOCS=OFF", "-DBUILD_JAVA=OFF", "-DBUILD_opencv_python2=OFF",
                           "-DBUILD_opencv_python3=OFF",
                           "-DWITH_IPP=OFF", "-DWITH_OPENCL=OFF", "-DWITH_OPENCLAMDBLAS=OFF",
                           "-DWITH_TBB=OFF", "-DWITH_EIGEN=OFF", "-DWITH_PROTOBUF=OFF",
                           "-DWITH_FFMPEG=OFF", "-DWITH_GSTREAMER=OFF", "-DWITH_1394=OFF",
                           "-DWITH_V4L=OFF", "-DWITH_FFMPEG=OFF", "-DWITH_GTK=OFF",
                           "-DBUILD_ZLIB=OFF", "-DBUILD_PNG=OFF", "-DBUILD_JPEG=OFF",
                           "-DBUILD_TIFF=OFF", "-DBUILD_WEBP=OFF", "-DBUILD_OPENJPEG=OFF",
                           "-DBUILD_JASPER=OFF", "-DENABLE_PRECOMPILED_HEADERS=OFF",
                           "-DENABLE_FAST_MATH=ON", "-DCV_ENABLE_INTRINSICS=OFF"}
        table.insert(configure, "-DCMAKE_C_FLAGS=" .. table.concat(FLAGS, " "))
        table.insert(configure, "-DCMAKE_CXX_FLAGS=" .. table.concat(FLAGS, " "))
        table.insert(configure, "-DCMAKE_INSTALL_PREFIX=" .. package:installdir())
        os.iorunv(table.join(configure, {"-S", os.curdir(), "-B", build}))

        os.iorunv({"cmake", "--build", build, "--target", "install", "--parallel", "5"})

        for _, name in ipairs({"core", "imgproc", "features2d", "flann", "calib3d"}) do
            local header = path.join("modules", name, "include", "opencv2")
            assert(os.isdir(header), "opencv " .. name .. " installed no headers")
            os.vcp(path.join(header, "**"), package:installdir("include"))
        end
        os.vcp("LICENSE", package:installdir("licenses"))
    end)

    on_test(function (package)
        assert(os.isfile(path.join(package:installdir("lib"), "libopencv_core.a")))
        assert(os.isfile(path.join(package:installdir("include"), "opencv2", "core.hpp")))
        -- the three calls the tracker's pose comes out of, and ORB, are in the library the ruling named
        local symbols = os.outputofv({"nm", "-gU", path.join(package:installdir("lib"), "libopencv_calib3d.a")})
        for _, name in ipairs({"findEssentialMat", "recoverPose", "solvePnPRansac"}) do
            assert(symbols:find(name, 1, true), "calib3d exports no " .. name)
        end
        local features = os.outputofv({"nm", "-gU", path.join(package:installdir("lib"), "libopencv_features2d.a")})
        assert(features:find("ORB", 1, true), "features2d exports no ORB")
    end)
