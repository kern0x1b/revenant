function failures(opt)
    return {"the dispatch_block probes in compat/device/ compare the shims with the libdispatch of the machine that runs them, and the class "
            .. "of the default global queue and of a queue made without one have no answer that the SDK header and this host agree on; "
            .. "those answer as iOS only on a device or an emulator, and this host runs macOS's libdispatch, with no device or emulator run "
            .. "of the probes wired into the test harness yet"}
end
