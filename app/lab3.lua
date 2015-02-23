require("storm") -- libraries for interfacing with the board and kernel
require("cord") -- scheduler / fiber library
LCD = require("lcd") -- lcd display
print ("Base  test ")

sh = require "stormsh"
Button = require("button")
cport=1525

sL = {"example1", "example2"}
sT={example1={"1234"}, example2={"78","90"}}
sS = {example1="setBool", example2="setBool"}
sO = {setBool={true, false}, setNumber={0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100}}

tB = Button:new("D4")
nB = Button:new("D3")

lcd = LCD:new(storm.i2c.EXT, 0x7c, storm.i2c.EXT, 0xc4)

cord.new(function() lcd:init(2, 1) end)
number=0

function notServ(list, service)
for i=1,#list do
	if list[i] == service then
		return false
	end
end
return true
end

function addToTable(from,payload)
	p=storm.mp.unpack(payload)
	if cState == 1 then 
		for k,v in pairs(p) do
			if k ~= "id" then
				if sT[k] == nil then
					sT[k] = {from}
					sS[k] = v.s
				else
					tempT = sT[k]
					table.insert(tempT, from)
					sT[k] = tempT
					sS[k] = v.s
				end
				if notServ(sL, k) then
					table.insert(sL, k)
				end
			end
		end
	end
end

function svc_stdout(from_ip, from_port,msg)
	print(string.format("[STDOUT] (ip=%s, port=%d) %s", from_ip, from_port, msg))
end

asock= storm.net.udpsocket(cport,
		function(payload, from, port)
		addToTable(from,payload)
		p=storm.mp.unpack(payload)
		print("table is")
end)

sendSock = storm.net.udpsocket(1526,
		function(payload, from, port)
			print("Received")
		end)

sI = 1
ipI = 1
cState = 1
oI = 1
cService = ""
cIP = ""
cOption = ""

scrolling = function()
	if cState == 1 then
		if #sL > 0 then
			if sI == #sL+1 then
				sI = 1
			end
			clearLCD()
			lcd:writeString(string.format("%s", sL[sI]))
			sI = sI + 1
		else
			clearLCD()
			lcd:writeString("No items")
		end
	elseif cState == 2 then
		cService = sL[sI-1]
		clearLCD()
		cIP = sT[cService][ipI]
		print(cService, cIP)
		lcd:writeString(string.format("%s", sT[cService][ipI]))
		ipI = ipI + 1
		if ipI == #sT[cService]+1 then
			ipI = 1
		end
	elseif cState == 3 then
		opt = sS[cService]
		if opt == "setBool" then
			cOption = sO[opt][oI]
			if cOption then
				str = "true"
			else
				str = "false"
			end
		elseif opt == "setNumber" then
			cOption = sO[opt][oI]
			str = string.format("%d", cOption)
		end
		clearLCD()
		lcd:writeString(str)
		oI  = oI + 1
		if oI == #sO[opt] then
			oI = 1
		end
	end
end


sendMessage = function(message)
	handle = storm.os.invokePeriodically(600*storm.os.MILLISECOND, function()
		print("Sending message")
		storm.net.sendto(sendSock, message, cIP, 1526)
	end)
	cord.await(storm.os.invokeLater, 5*storm.os.SECOND)
	storm.os.cancel(handle)
end

enter = function()
	clearLCD()
	if cState == 1 then
		lcd:writeString("Touch to see IP addresses")
	elseif cState == 2 then
		lcd:writeString("Touch to see options")
	elseif cState == 3 then
		lcd:writeString("Sending request")
		message = {cService, {cOption}}
		packedMessage = storm.mp.pack(message)
		sendMessage(packedMessage)
		--print("Sending", cService, cOption)
	end
	cState = cState + 1
	if cState == 4 then
		cState = 1
		ipI = 1
		sI = 1
		oI = 1
	end
end

clearLCD = function()
	lcd:writeString("                                ")
end

callService = function()
end

tB:whenever("RISING", function()
		cord.new(function() scrolling() end)
			end)

nB:whenever("RISING", function()
		cord.new(function() enter() end)
			end)

local svc_manifest = {id="Potato"}
local msg = storm.mp.pack(svc_manifest)
storm.os.invokePeriodically(5*storm.os.SECOND, function()
storm.net.sendto(asock,msg, "ff02::1", 1525)
end)

-- start a shell so you can play more
-- start a coroutine that provides a REPL
sh.start()

-- enter the main event loop. This puts the processor to sleep
-- in between events
cord.enter_loop()
