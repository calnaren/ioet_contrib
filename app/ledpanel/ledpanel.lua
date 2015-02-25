
require "cord"
require "math"
require "svcd"
local LED = require "led"

lr = LED:new("D4")
lg = LED:new("D5")
lb = LED:new("D6")

MOTDs = {"Default message!!1" }

SVCD.init("ledpanel", function()
    print "starting"
    SVCD.add_service(0x3003)
    -- LED flash attribute
    SVCD.add_attribute(0x3003, 0x4005, function(pay, srcip, srcport)
        local ps = storm.array.fromstr(pay)
        local lednum = ps:get(1)
        local flashcount = ps:get(2)
        print ("got a request to flash led",lednum, " x ", flashcount)

        if lednum == 0 then
            lr:flash(flashcount,300)
        end
        if lednum == 1 then
            lg:flash(flashcount,300)
        end
        if lednum == 2 then
            lb:flash(flashcount,300)
        end
    end)
    -- LED control attribute
    SVCD.add_attribute(0x3003, 0x4006, function(pay, srcip, srcport)
        local ps = storm.array.fromstr(pay)
        local lednum = ps:get(1)
        local duration = ps:get_as(storm.array.INT16, 1)
        print ("got a request to turn on led",lednum, " for ", duration)
        local target
        if lednum == 0 then
            target=lr
        end
        if lednum == 1 then
            target=lg
        end
        if lednum == 2 then
            target=lb
        end

        if duration > 0 then
            target:on()
            storm.os.invokeLater(duration*storm.os.MILLISECOND, function()
                target:off()
            end)
        elseif duration == 0 then
            target:off()
        else
            target:on()
        end
    end)

    -- MOTD attribute
    SVCD.add_attribute(0x3003, 0x4008, function(pay, srcip, srcport)
        local parr = storm.array.fromstr(pay)
        -- Little hack to trim the length of the string to 19 max
        -- Because the bluetooth notify only allows 20
        if parr:get(1) > 19 then parr:set(1, 19) end
        -- remember that in our protocol we use pascal strings
        table.insert(MOTDs, parr:get_pstring(0))
    end)

    cord.new(function()
        while true do
            local msg = MOTDs[math.random(1,#MOTDs)]
            local arr = storm.array.create(#msg+1,storm.array.UINT8)
            arr:set_pstring(0, msg)
            SVCD.notify(0x3003, 0x4008, arr:as_str())
            cord.await(storm.os.invokeLater, 3*storm.os.SECOND)
        end
    end)
end)


cord.enter_loop()

