require("storm") -- libraries for interfacing with the board and kernel
require("cord") -- scheduler / fiber library

----------------------------------------------
-- Buzzer class
--   basic Buzzer functions associated with a shield pin
--   assume cord.enter_loop() is active, as per stormsh
----------------------------------------------
local Buzzer = {}

function Buzzer:new(buzzerpin)
   assert(buzzerpin and storm.io[buzzerpin], "invalid pin spec")
   obj = {pin = buzzerpin, running = false}		-- initialize the new object
   setmetatable(obj, self)	-- associate class methods
   self.__index = self
   storm.io.set_mode(storm.io.OUTPUT, storm.io[buzzerpin])
   return obj
end

function Buzzer:pin()
   return self.pin
end

function Buzzer:start(period)
    period = period or 0
    self.running = true
    cord.new(function ()
        while self.running do
            storm.io.set(1, storm.io[self.pin])
            storm.io.set(0, storm.io[self.pin])
            if period == 0 then
                cord.yield()
            else
                cord.await(storm.os.invokeLater, period)
            end
        end
    end)
end    

function Buzzer:stop()
    self.running = false
end

return Buzzer

