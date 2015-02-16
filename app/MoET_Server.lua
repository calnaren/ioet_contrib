require "cord" -- scheduler / fiber library
LCD = require("lcd")
TEMP = require("temp")

print("echo test")

ipaddr = storm.os.getipaddr()
ipaddrs = string.format("%02x%02x:%02x%02x:%02x%02x:%02x%02x::%02x%02x:%02x%02x:%02x%02x:%02x%02x",
			ipaddr[0],
			ipaddr[1],ipaddr[2],ipaddr[3],ipaddr[4],
			ipaddr[5],ipaddr[6],ipaddr[7],ipaddr[8],	
			ipaddr[9],ipaddr[10],ipaddr[11],ipaddr[12],
			ipaddr[13],ipaddr[14],ipaddr[15])

print("ip addr", ipaddrs)
print("node id", storm.os.nodeid())
cport = 49352
successes = 0
iterations = 0
tempValue = 0

function lcd_setup()
	lcd = LCD:new(storm.i2c.EXT, 0x7c, storm.i2c.EXT, 0xc4)
	cord.new(function() lcd:init(2,1) lcd:setBackColor(20,20,20) end)
end

function temp_setup()
	temp = TEMP:new()
	cord.new(function() temp:init() end)
end

function stringStarts(String,Start)
   return string.sub(String,1,string.len(Start))==Start
end

function stringEnds(String,End)
   return End=='' or string.sub(String,-string.len(End))==End
end


--create echo server as handler
server = function()
   lcd_setup()
   temp_setup()
   ssock = storm.net.udpsocket(7,serverHandler)
   print("Server started")
end

serverHandler = function(payload, from, port)
	--cord.new(function() 
		iterations = iterations + 1
		if payload and stringStarts(payload,"1") then
			successes = successes + 1
			local count = string.sub(payload,3,string.len(payload))
			print("Received Data 1")
			--cord.new(function() lcd:setBackColor(200,50,50) end)
			--cord.new(function() lcd:clear() end)
			--cord.new(function() lcd:writeString(string.format("Network: %d of %s packets received",successes,count)) end)
			if iterations >= 5 then 
				cord.new(function() lcd:setBackColor(20,100,20) lcd:writeString(string.sub("Network:        " .. successes*100/count .. "." .. successes*1000/count % 10 .. "%" .. " received                     ",1,32)) end)
				iterations = 0
			end
		elseif payload and stringStarts(payload,"2") then
			successes = 0
			local value = string.sub(payload,3,string.len(payload))
			print("Received Data 2")
			if iterations >= 5 then 
				cord.new(function() lcd:setBackColor(20,20,100) lcd:writeString(string.sub("Acc XYZ:        " .. value .. "                                         ",1,32)) end)
				iterations = 0
			end
			
		elseif payload and stringStarts(payload,"3") then
			successes = 0
			--local value = string.sub(payload,3,string.len(payload))
			cord.new(function() tempValue = temp:getTemp() end)
			print("Received Data 3")
			if iterations >= 5 then 
				cord.new(function() lcd:setBackColor(100,20,20) lcd:writeString(string.sub("Temperature:    " .. tempValue .. string.char(0xdf) ..  "C                                         ",1,32)) end)
				iterations = 0
			end
			
		end
	--end)
end

server()

-- enable a shell
sh = require "stormsh"
sh.start()
cord.enter_loop() -- start event/sleep loop
