local MUTATIONS = {
    beginpass = {
        [==[            for (AVAssetWriterInput *each in self_.inputs)
                revenant_begin_pass(each);]==],
        [==[            for (AVAssetWriterInput *each in self_.inputs)
                (void)each;]==],
    },
    ranges = {
        "CMTimeRangeMake(kCMTimeZero, kCMTimePositiveInfinity)",
        "CMTimeRangeMake(kCMTimeZero, kCMTimeZero)",
    },
    finalcall = {
        [==[    dispatch_queue_t queue = objc_getAssociatedObject(self, &revenant_multipass_queue);
    if (queue) {
        dispatch_async(queue, ^{
            revenant_invoke_pass_callback(self);
        });
    }]==],
        "    (void)0;",
    },
    forward = {
        [==[    revenant_end_pass(self);
    dispatch_queue_t queue]==],
        [==[    revenant_end_pass(self);
    [self markAsFinished];
    dispatch_queue_t queue]==],
    },
    setafter = {
        [==[    if (objc_getAssociatedObject(self, &revenant_multipass_writing))
        revenant_raise(@"-[AVAssetWriterInput setPerformsMultiPassEncodingIfSupported:] cannot be called after the input's asset writer has started writing");]==],
        "    (void)0;",
    },
    exportafter = {
        [==[    if (objc_getAssociatedObject(self, &revenant_export_started))
        revenant_raise(@"-[AVAssetExportSession setCanPerformMultiplePassesOverSourceMediaData:] cannot be called after the export has started");]==],
        "    (void)0;",
    },
}

function main(path_name, which)
    local pair = MUTATIONS[which]
    if pair == nil then
        raise("FAIL: no such mutant: " .. tostring(which))
    end
    local text = io.readfile(path_name, {encoding = "binary"})
    local first, last = text:find(pair[1], 1, true)
    if first == nil then
        io.stderr:write(string.format("the %s mutation did not apply, so this run proves nothing\n", which))
        os.exit(1)
    end
    io.writefile(path_name, text:sub(1, first - 1) .. pair[2] .. text:sub(last + 1), {encoding = "binary"})
    print("# applied the " .. which .. " mutation")
end
