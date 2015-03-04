require "cord"
LCD = require "lcd"

function lcd_setup()
	lcd = LCD:new(storm.i2c.EXT, 0x7c, storm.i2c.EXT, 0xc4)
	cord.new(function() lcd:init(2,1) lcd:setBackColor(20,20,20) end)
end

function onconnect(state)
   if tmrhandle ~= nil then
       storm.os.cancel(tmrhandle)
       tmrhandle = nil
   end
   if state == 1 then
       storm.os.invokePeriodically(1*storm.os.SECOND, function()
           tmrhandle = storm.bl.notify(char_handle, 
              string.format("Time: %d", storm.os.now(storm.os.SHIFT_16)))
       end)
   end
end


storm.bl.enable("unused", onconnect, function()
   local svc_handle = storm.bl.addservice(0x1337)
   char_handle = storm.bl.addcharacteristic(svc_handle, 0x1338, function(x)
        cord.new(function() lcd:setBackColor(string.byte(string.sub(x, 1, 1)), string.byte(string.sub(x, 2, 2)), string.byte(string.sub(x, 3, 3))) end)
       print ("received: ",string.byte(string.sub(x, 1, 1)), string.sub(x, 2, 2), string.sub(x, 3, 3))
   end)
end)

lcd_setup()

sh = require "stormsh"
sh.start()
cord.enter_loop()
