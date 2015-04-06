
require "cord"
sh = require "stormsh"
sh.start()
-- in global scope now
require "svcd"

strips = {}

--[[SVCD.init("fsrserver", function()
    SVCD.add_service(0x300a)
    
    SVCD.add_attribute(0x300a, 0x400e, function(pay, srcip, srcport)
    end)

    cord.new(function()
        while true do
            print ("sending FSR notifications")
	    storm.n.adcife_init()
	    local val = storm.n.adcife_sample_an0(2)
	    local val_str = tostring(val)
            local arr = storm.array.create(#val_str+1, storm.array.UINT8)
            arr:set_pstring(0, val_str)
            SVCD.notify(0x300a, 0x400e, arr:as_str())
            cord.await(storm.os.invokeLater, 1*storm.os.SECOND)
        end
    end)
end)]]--

discoveredLED = false

cord.new(function()
    cord.await(SVCD.init, "ledclient")
    SVCD.advert_received = function(pay, srcip, srcport)
        local adv = storm.mp.unpack(pay)
        for k,v in pairs(adv) do
            --These are the services
            if k == 0x3009 then
                --Characteristic
                for kk,vv in pairs(v) do
                    if vv == 0x400a and k == 0x3009 then
                        -- This is a supernight LED set service
                        if strips[srcip] == nil then
                            print ("Discovered LED strips: ", srcip)
                            discoveredLED = true
                        end
                        strips[srcip] = storm.os.now(storm.os.SHIFT_16)
                    end        
                end
            end
        end
    end
end)

-- Set a particular LED
function setled(position, red, green, blue)
    cord.new(function()
        for k, v in pairs(strips) do
            local cmd = storm.array.create(4, storm.array.UINT8)
            cmd:set(1, position)
            cmd:set(2, red)
            cmd:set(3, green)
            cmd:set(4, blue)
            local stat = cord.await(SVCD.write, k, 0x3009, 0x400a, cmd:as_str(), 300)
            if stat ~= SVCD.OK then
                --print "FAIL"
            else
                --print "OK"
            end
            -- don't spam
            cord.await(storm.os.invokeLater,50*storm.os.MILLISECOND)
        end
    end)
end

-- Show the entire strip
function showled()
    cord.new(function()
        for k, v in pairs(strips) do
            local cmd = storm.array.create(1, storm.array.UINT8)
            local stat = cord.await(SVCD.write, k, 0x3009, 0x400b, cmd:as_str(), 300)
            if stat ~= SVCD.OK then
                print "FAIL"
            else
                print "OK"
            end
            -- don't spam
            cord.await(storm.os.invokeLater,50*storm.os.MILLISECOND)
        end
    end)
end

-- Clear the entire strip
function clearled()
    cord.new(function()
        for k, v in pairs(strips) do
            local cmd = storm.array.create(1, storm.array.UINT8)
            local stat = cord.await(SVCD.write, k, 0x3009, 0x400c, cmd:as_str(), 300)
            if stat ~= SVCD.OK then
                print "FAIL"
            else
                print "OK"
            end
            -- don't spam
            cord.await(storm.os.invokeLater,50*storm.os.MILLISECOND)
        end
    end)
end

-- Clear a particular LED on the strip
function clearspecificled(position)
    cord.new(function()
        for k, v in pairs(strips) do
            local cmd = storm.array.create(1, storm.array.UINT8)
            cmd:set(1, position)
            local stat = cord.await(SVCD.write, k, 0x3009, 0x400d, cmd:as_str(), 300)
            if stat ~= SVCD.OK then
                print "FAIL"
            else
                print "OK"
            end
            -- don't spam
            cord.await(storm.os.invokeLater,50*storm.os.MILLISECOND)
        end
    end)
end

cord.new(function()
        while true do
            if discoveredLED == true then
                storm.n.adcife_init()
                val = storm.n.adcife_sample_an0(0)
                if val < 2070 then
                        val = 2070
                end
                if val > 4000 then
                        val = 4000
                end
                val = val - 2070
                level = 50 * val/(4000-2070)
                red, green, blue = storm.n.val2rgb(val, level, 50)
                for i=0,49 do
                        if i <= level then
                                setled(i, red/8, green/8, blue/8)
                                cord.await(storm.os.invokeLater, 100*storm.os.MILLISECOND)
                        else
                                setled(i, 0, 0, 0)
                                cord.await(storm.os.invokeLater, 100*storm.os.MILLISECOND)
                        end
                end
                showled()
                cord.await(storm.os.invokeLater, 1000*storm.os.MILLISECOND)
            else
                cord.await(storm.os.invokeLater, 1000*storm.os.MILLISECOND)
            end
        end
end)

cord.enter_loop()

