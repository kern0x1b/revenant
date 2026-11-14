function newer_source(binary, sources)
    local built = os.mtime(binary)
    local newest, newest_time
    for _, source in ipairs(sources) do
        if os.isfile(source) then
            local time = os.mtime(source)
            if time > built and (not newest_time or time > newest_time) then
                newest, newest_time = source, time
            end
        end
    end
    return newest
end
