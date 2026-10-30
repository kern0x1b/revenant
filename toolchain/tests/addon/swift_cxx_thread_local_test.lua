function failures(opt)
    return import("swift_cxx", {anonymous = true}).failures(opt, "thread_local", {"@rpath/libc++abi.1.dylib"}, {
        emulated = {"___emutls_get_address"},
        native = {"__tlv_bootstrap"}
    })
end
