require("storm") -- libraries for interfacing with the board and kernel
require("cord") -- scheduler / fiber library
LCD = require("lcd") -- lcd display
print ("Base  test ")

sh = require "stormsh"
shield = require("starter")

cport=1525

table={}
flattened_table={}

shield.Button.start()
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
function addToTable(from,payload)
	p=storm.mp.unpack(payload)
	for k,v in pairs(p) do
		if table[from]==nil then
			table[from]={}
		end
		if k ~= "id" then
		if table[from][k]==nil then
				flattened_table[number]=string.format("%s,%s",from,k)--flat(from,v)
				number=number+1
			end
			table[from][k]=v
			
		end
	end
end

function svc_stdout(from_ip, from_port,msg)
	print(string.format("[STDOUT] (ip=%s, port=%d) %s", from_ip, from_port, msg))
	-- lcd:writeString(string.format("[STDOUT] (ip=%s, port=%d) %s", from_ip, from_port, msg))
end

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
					end
				else
					--print(k,i,j)
					lcd:writeString(string.format("%s %s", k, i))
				end
			end
		end
	end
end)

asock= storm.net.udpsocket(cport,
		function(payload, from, port)
		addToTable(from,payload)
		p=storm.mp.unpack(payload)
		--print(string.format("echo %s %d:%s",from,port,p["id"]))
		print("table is")
		pprint(table)
		--print("flattened_table\n")
		for k,v in pairs(flattened_table) do 
			print(k,v)
		end
end)

upService = function()
end

downService = function()
end

callService = function()
end

shield.Button.whenever(1, "RISING",function() 
                cord.new(function() upService() end)
		      end)

shield.Button.whenever(2, "RISING",function() 
                cord.new(function() downService() end)
		      end)

shield.Button.whenever(3, "RISING",function() 
                cord.new(function() callService() end)
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
