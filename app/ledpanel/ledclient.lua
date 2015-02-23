
require "cord"
sh = require "stormsh"
sh.start()
local svcd = require "svcd"

flashers = {}

cord.new(function()
    cord.await(svcd.init, "ledclient")
    svcd.advert_received = function(pay, srcip, srcport)
        local adv = storm.mp.unpack(pay)
        for k,v in pairs(adv) do
            --These are the services
            if k == 0x3003 then
                --Characteristic
                for kk,vv in pairs(v) do
                    if vv == 0x4005 and k == 0x3003 then
                        -- This is an LEDPanel flash service
                        if flashers[srcip] == nil then
                            print ("Discovered LED panel: ", srcip)
                        end
                        flashers[srcip] = storm.os.now(storm.os.SHIFT_16)
                    end
                end
            end
        end
    end
end)

function flashem(lednum, times)
    cord.new(function()
        for k, v in pairs(flashers) do
            local cmd = storm.array.create(2, storm.array.UINT8)
            cmd:set(1,lednum)
            cmd:set(2,times)
            local stat = cord.await(svcd.write, k, 0x3003, 0x4005, cmd:as_str(), 300)
            if stat ~= svcd.OK then
                print "FAIL"
            else
                print "OK"
            end
            -- don't spam
            cord.await(storm.os.invokeLater,50*storm.os.MILLISECOND)
        end
    end)
end

function get_motd(serial)
    svcd.subscribe("fe80::212:6d02:0:"..serial,0x3003, 0x4008, function(msg)
        local arr = storm.array.fromstr(msg)
        print ("Got MOTD: ",arr:get_pstring(0))
    end)
end

cord.enter_loop()

