Advertiser = require "advertiser"
require "cord"

adv = Advertiser:new("tester")
adv:addService("echo", "disp", "echoes argument", function (message)
    return message
end)

adv:advertiseRepeatedly(storm.os.SECOND)

cord.enter_loop()
