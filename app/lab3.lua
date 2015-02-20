require("storm") -- libraries for interfacing with the board and kernel
require("cord") -- scheduler / fiber library
LCD = require("lcd") -- lcd display
print ("Base  test ")

sh = require "stormsh"
--shield = require("starter")
Button = require("button")
cport=1525

serviceList = {"example1", "example2"}
serviceTable={example1={"1234"}, example2={"78","90"}}
serviceOptions = {setBool={true, false}}
--flattened_table={}

touchButton = Button:new("D4")
normalButton = Button:new("D3")

--shield.Button.start()
lcd = LCD:new(storm.i2c.EXT, 0x7c, storm.i2c.EXT, 0xc4)

cord.new(function() lcd:init(2, 1) end)
number=0
--[[
function flat(ip,entry)
	for i,j in pairs(v) do
		if type(j)=="table" then 
			for a,b in pairs(j) do 
				return string.format("%s,%s",ip,i)	
			end
		else
			print()
		end
	end
end
]]--

function notHasService(list, service)
for i=1,#list do
	if list[i] == service then
		return false
	end
end
return true
end

function addToTable(from,payload)
	p=storm.mp.unpack(payload)
	for k,v in pairs(p) do
--		if serviceTable[from]==nil then
--			serviceTable[from]={}
--		end
		if k ~= "id" then
--		if table[from][k]==nil then
--				flattened_table[number]=string.format("%s,%s",from,k)--flat(from,v)
--				number=number+1
--			end
			if serviceTable[k] == nil then
				serviceTable[k] = {from}
			else
				table.insert(serviceTable[k], from)
			end
			if notHasService(serviceList, k) then
				table.insert(serviceList, k)
			end
		end
	end
end

function svc_stdout(from_ip, from_port,msg)
	print(string.format("[STDOUT] (ip=%s, port=%d) %s", from_ip, from_port, msg))
	-- lcd:writeString(string.format("[STDOUT] (ip=%s, port=%d) %s", from_ip, from_port, msg))
end
--[[
function pprint(table)
	print(" ")
	for k,v in pairs(table) do
		for i,j in pairs(v) do
			if type(j)=="table" then 
				for a,b in pairs(j) do 
					print(k,i,a,b)
				end
			else
				print(k,i,j)
			end
		end
	end
	print(" ")
end
]]--
--[[
cord.new(function()
	while true do
		cord.await(storm.os.invokeLater, 1000*storm.os.MILLISECOND)
		--lcd:clear()
		for k,v in pairs(table) do
			for i,j in pairs(v) do
				if type(j)=="table" then 
					for a,b in pairs(j) do 
						--print(k,i,a,b)
						lcd:writeString(string.format("%s %s", k, i))
						cord.await(storm.os.invokeLater, 1000*storm.os.MILLISECOND)
					end
				else
					--print(k,i,j)
					lcd:writeString(string.format("%s %s", k, i))
					cord.await(storm.os.invokeLater, 1000*storm.os.MILLISECOND)
				end
			end
		end
	end
end)
]]--

cord.new(function()


end)

asock= storm.net.udpsocket(cport,
		function(payload, from, port)
		addToTable(from,payload)
		p=storm.mp.unpack(payload)
		--print(string.format("echo %s %d:%s",from,port,p["id"]))
		print("table is")
		--pprint(table)
		--print("flattened_table\n")
--		for k,v in pairs(flattened_table) do 
--			print(k,v)
--		end
end)

sendSock = storm.net.udpsocket(1526,
		function(payload, from, port)
			print("Received")
		end)

serviceIndex = 1
ipIndex = 1
currentState = 1
optionsIndex = 1
currentService = ""
currentIP = ""
currentOption = ""

scrolling = function()
	if currentState == 1 then
		if #serviceList > 0 then
			if serviceIndex == #serviceList+1 then
				serviceIndex = 1
			end
			--lcd:clear()
			clearLCD()
			lcd:writeString(string.format("%s", serviceList[serviceIndex]))
			serviceIndex = serviceIndex + 1
		else
			--lcd:clear()
			clearLCD()
			lcd:writeString("No items")
		end
	elseif currentState == 2 then
		currentService = serviceList[serviceIndex]
		clearLCD()
		currentIP = serviceTable[currentService][ipIndex]
		print(currentService, currentIP)
		lcd:writeString(string.format("%s", serviceTable[currentService][ipIndex]))
		ipIndex = ipIndex + 1
		if ipIndex == #serviceTable[currentService]+1 then
			ipIndex = 1
		end
	elseif currentState == 3 then
		currentOption = serviceOptions["setBool"][optionsIndex]
		if currentOption then
			str = "true"
		else
			str = "false"
		end
		lcd:writeString(str)
		optionsIndex  = optionsIndex + 1
		if optionsIndex == 3 then
			optionsIndex = 1
		end
	end
end

sendMessage = function(message)
	handle = storm.os.invokePeriodically(600*storm.os.MILLISECOND, function()
		storm.net.sendto(sendSock, message, currentIP, 1526)
	end)
	cord.await(storm.os.invokeLater, 10*storm.os.SECOND)
	storm.os.cancel(handle)
end

enter = function()
	clearLCD()
	if currentState == 1 then
		lcd:writeString("Touch to see IP addresses")
	elseif currentState == 2 then
		--lcd.writeString("Touch to see options")
	elseif currentState == 3 then
		--lcd.writeString("Sending request")
		message = {currentService, {currentOption}}
		packedMessage = storm.mp.pack(message)
		sendMessage(packedMessage)
	end
	currentState = currentState + 1
	if currentState == 4 then
		currentState = 1
		ipIndex = 1
		serviceIndex = 1
	end
end

clearLCD = function()
	lcd:writeString("                                ")
end

callService = function()
end
--[[
shield.Button.whenever(1, "RISING",function() 
                cord.new(function() upService() end)
		      end)

shield.Button.whenever(2, "RISING",function() 
                cord.new(function() downService() end)
		      end)

shield.Button.whenever(3, "RISING",function() 
                cord.new(function() callService() end)
		      end)
]]--

touchButton:whenever("RISING", function()
		cord.new(function() scrolling() end)
			end)

normalButton:whenever("RISING", function()
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
