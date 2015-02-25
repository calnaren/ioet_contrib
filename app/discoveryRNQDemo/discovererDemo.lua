Discoverer = require "discoverer"
require "cord"

print("")

pt = function (t) for k, v in pairs(t) do print(k, v) end end

-- Generally, you'll want a timeout period longer than 20 seconds
d = Discoverer:new(function (ip, port, id, name, service)
        print("found " .. name .. ":")
        pt(service)
        print("invoking " .. name .. " on \"abc\"")
        d:invoke(ip, name, {"abc"}, nil, nil, nil, function (message)
            print("got return values as table:")
            pt(message)
        end)
    end, function (ip, port, id, name, service)
        print("lost", k)
        pt(service)
    end, 20 * storm.os.SECOND)

cord.enter_loop()
