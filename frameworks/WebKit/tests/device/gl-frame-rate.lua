local USAGE = [[usage: ./xmakew l frameworks/WebKit/tests/device/gl-frame-rate.lua [HOST]
  measures how fast a WebGL canvas keeps drawing in Safari on the phone, at three canvas sizes,
  and fails when the last size never reports, which is what a freeze looks like.]]

function main(host)
    if host == "--help" then
        print(USAGE)
        return
    end
    local harness = import("harness", {rootdir = os.scriptdir(), anonymous = true})
    host = host or harness.host_address()
    local port = harness.port(8899)
    local phone = harness.phone()
    local verdict = harness.with_server(port, {}, function (server)
        os.sleep(1000)
        phone:restart_safari(6)
        phone:open_url(string.format("http://%s:%d/gl-frame-rate.html?run=%d", host, port, harness.run_token()))
        server:wait_for("320x480%%3D", 40, 3)
        return server:last_report()
    end)
    print("webgl frame rate: " .. (verdict ~= "" and verdict or "nothing reported"))
    if not verdict:find("320x480=", 1, true) then
        raise("the canvas stopped drawing before its last size")
    end
end
