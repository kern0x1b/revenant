local USAGE = [[usage: ./xmakew l frameworks/WebKit/tests/device/sweep.lua [URL...]
  loads the pages you name in Safari on the phone, one browser each, and reports whether the browser
  survived, how often the crash handler fired, how much of the page area was painted and the process's
  dirty memory. With no URL it reads tests/device/sweep-sites.txt, which is the operator's and is
  gitignored: which sites an automated run drives a browser at is the operator's call, so none ship here.]]

local dirty = [[P=$(revpid MobileSafari | sed -n "1s/ .*//p"); if [ -n "$P" ]; then revmem $P | sed -n "s/.*dirty=\([0-9.]*\) MB.*/\1 MB/p"; fi]]

local crash_log = "/tmp/rev-safari-stderr.log"

local function row(...)
    return string.format("%-46s %-6s %-6s %-10s %s", ...)
end

local function listed_sites(file)
    local sites = {}
    if os.isfile(file) then
        for line in io.readfile(file):gmatch("[^\n]+") do
            if line ~= "" and not line:startswith("#") then
                table.insert(sites, line)
            end
        end
    end
    return sites
end

local function shot_name(url)
    return ((url:gsub("^https?://", ""):gsub("[/?=&+]", "_")):sub(1, 46))
end

local function sweep(harness, phone, url)
    phone:run("killall MobileSafari 2>/dev/null; rm -f " .. crash_log)
    os.sleep(6000)
    phone:open_url(url)
    os.sleep(26000)
    local alive = phone:run("killall -0 MobileSafari 2>/dev/null && echo 1 || echo 0"):trim()
    local crashes = phone:run("if [ -f " .. crash_log .. " ]; then grep -c REVCRASH " .. crash_log .. "; echo; fi"):trim()
    local painted, memory = "-", "-"
    if alive == "1" then
        memory = phone:run(dirty):trim()
        painted = harness.painted(phone:screenshot(shot_name(url) .. ".png"))
    end
    return alive, crashes ~= "" and crashes or "?", painted ~= "" and painted or "?", memory ~= "" and memory or "?"
end

function main(...)
    local sites = {...}
    if sites[1] == "--help" then
        print(USAGE)
        return
    end
    local harness = import("harness", {rootdir = os.scriptdir(), anonymous = true})
    if #sites == 0 then
        sites = listed_sites(path.join(harness.folder(), "sweep-sites.txt"))
    end
    if #sites == 0 then
        print(USAGE)
        raise("name a page or list some in tests/device/sweep-sites.txt")
    end
    local phone = harness.phone()
    print(row("SITE", "ALIVE", "CRASH", "PAINTED", "DIRTY"))
    for _, url in ipairs(sites) do
        print(row(url, sweep(harness, phone, url)))
    end
end
