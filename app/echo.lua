--[[
   echo client as server
   currently set up so you should start one or another functionality at the
   stormshell

--]]

require "cord" -- scheduler / fiber library
LED = require("led")
brd = LED:new("GP0")

Button = require("button")
btn1 = Button:new("D9")		-- button 1 on starter shield
btn2 = Button:new("D10")	-- button 2 on starter shield
btn3 = Button:new("D11")	-- button 3 on starter shield
blu = LED:new("D2")		-- LEDS on starter shield
grn = LED:new("D3")
red = LED:new("D4")

print("echo test")
brd:flash(4)

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

-- create echo server as handler
server = function()
   ssock = storm.net.udpsocket(7, 
			       function(payload, from, port)
				  red:flash(1)
				  print (string.format("from %s port %d: %s",from,port,payload))
				  print(storm.net.sendto(ssock, payload, from, port))
				  red:flash(1)
			       end)
end

server()			-- every node runs the echo server

-- client side
count = 0
-- create client socket
csock = storm.net.udpsocket(cport, 
			    function(payload, from, port)
			       red:flash(3)
			       print (string.format("echo from %s port %d: %s",from,port,payload))
			    end)

-- send echo on each button press
clientNetwork = function()
   buttonType = 0
   count = 0
   while buttonType == 0 do
      blu:flash(1)
      --local msg = string.format("0x%04x says count=%d", storm.os.nodeid(), count)
      local msg = string.format("%d", count)
      print("1:", msg)
      -- send upd echo to link local all nodes multicast
      storm.net.sendto(csock, msg, "ff02::1",7) 
      count = count + 1
   end
   --grn:flash(1)
end

-- send echo on each button press
clientAccelerometer = function()
   buttonType = 1
   while buttonType == 1 do
      blu:flash(1)
      local msg = string.format("accelerometer")
      print("2:", msg)
      -- send upd echo to link local all nodes multicast
      storm.net.sendto(csock, msg, "ff02::1",7) 
   end
   grn:flash(1)
end

-- send echo on each button press
clientMagnetometer = function()
   grn:flash(1)
   local msg = string.format("magnetometer")
   print("3:", msg)
   -- send upd echo to link local all nodes multicast
   storm.net.sendto(csock, msg, "ff02::1",7) 
   grn:flash(1)
end

-- button press runs client
btn1:whenever("RISING",function() 
		print("Run client Network")
		clientNetwork() 
		      end)

-- button press runs client
btn2:whenever("RISING",function() 
		print("Run client Accelerometer")
		clientAccelerometer() 
		      end)

-- button press runs client
btn3:whenever("RISING",function() 
		print("Run client Gyroscope")
		clientMagnetometer() 
		      end)
-- enable a shell
sh = require "stormsh"
sh.start()
cord.enter_loop() -- start event/sleep loop
