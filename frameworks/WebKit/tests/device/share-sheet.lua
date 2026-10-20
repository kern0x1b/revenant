local USAGE = [[usage: ./xmakew l frameworks/WebKit/tests/device/share-sheet.lua
  opens navigator.share from a secure page on the phone, then cancels the sheet. The page arrives
  through a reverse SSH tunnel as http://localhost, a secure context, and revtouch taps the button
  and then Cancel. Fails unless the promise rejects with AbortError. TEST_PORT, 8903 by default.]]

function main(first)
    if first == "--help" then
        print(USAGE)
        return
    end
    local harness = import("harness", {rootdir = os.scriptdir(), anonymous = true})
    local port = harness.port(8903)
    local phone = harness.phone()
    local result = harness.with_server(port, {bind = "127.0.0.1"}, function (server)
        os.sleep(1000)
        phone:restart_safari(4)
        local tunnel = phone:reverse_tunnel(port)
        local seen
        local ok, errors = true, nil
        try {
            function ()
                os.sleep(3000)
                phone:open_url(string.format("http://localhost:%d/share-sheet.html?run=%d", port, harness.run_token()))
                os.sleep(10000)
                print("on load:   " .. server:last_report())
                phone:run("/usr/bin/revtouch tap 160 110")
                os.sleep(6000)
                phone:screenshot("share-sheet.png")
                phone:run("/usr/bin/revtouch tap 160 438")
                os.sleep(6000)
                seen = server:last_report()
            end,
            catch {
                function (raised)
                    ok, errors = false, raised
                end
            }
        }
        tunnel:kill()
        tunnel:close()
        if not ok then
            raise(errors)
        end
        return seen
    end)
    print("after cancel: " .. result)
    if result ~= "rejected AbortError" then
        raise("cancelling the share sheet did not reject the promise with AbortError")
    end
end
