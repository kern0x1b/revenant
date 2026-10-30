function failures(opt)
    return import("swift_cxx", {anonymous = true}).failures(opt, "std", {"@rpath/libswiftCxx.dylib", "@rpath/libswiftCxxStdlib.dylib"})
end
