local MUTATIONS = {
    rate = {"    return _rate;", "    return 1.0f;"},
    detachclock = {
        "        CMTimebaseSetRate(rendererTimebase, 0.0);\n        CMTimebaseSetTime(rendererTimebase, kCMTimeZero);",
        "        CMTimebaseSetRate(rendererTimebase, CMTimebaseGetRate(_timebase));",
    },
    periodicinterval = {
        "        [self revenant_armAt:CMTimeAdd(now, self->interval)];",
        "        [self revenant_armAt:now];",
    },
    removeobserver = {
        "    if (![_observers containsObject:observer])\n        return;\n    [_observers removeObject:observer];",
        "    return;",
    },
    addtwice = {
        "    if ([_renderers containsObject:renderer])\n        [NSException raise:NSInvalidArgumentException\n                    format:@\"-[AVSampleBufferRenderSynchronizer addRenderer:] cannot add the same renderer twice\"];",
        "    (void)0;",
    },
    boundarypast = {
        "        if (!CMTIME_IS_NUMERIC(time) || CMTimeCompare(time, now) <= 0)\n            continue;",
        "        (void)now;",
    },
    emptytimes = {
        "    if (!times.count)\n        [NSException raise:NSInvalidArgumentException\n                    format:@\"-[AVSampleBufferRenderSynchronizer addBoundaryTimeObserverForTimes:queue:usingBlock:] needs at least one time\"];",
        "    (void)0;",
    },
    flushstatus = {
        "    [self revenant_reportReadiness];\n}\n\n- (void)flushFromSourceTime:",
        "    _status = AVQueuedSampleBufferRenderingStatusRendering;\n    [self revenant_reportReadiness];\n}\n\n- (void)flushFromSourceTime:",
    },
    readiness = {"        return _pending.count == 0;", "        return YES;"},
    volume = {
        "    _volume = volume;\n    [self revenant_applyVolume];",
        "    _volume = 1.0f;\n    [self revenant_applyVolume];",
    },
    nodynamic = {
        "@dynamic allowedAudioSpatializationFormats;",
        "// (the @dynamic for allowedAudioSpatializationFormats is gone)",
    },
    raterenderers = {
        "        CMTimebaseSetRate(renderer.timebase, rate);\n        if ([renderer respondsToSelector:@selector(revenant_renderSynchronizerDidChangeRate)])",
        "        if ([renderer respondsToSelector:@selector(revenant_renderSynchronizerDidChangeRate)])",
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
