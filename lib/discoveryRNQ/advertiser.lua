require "storm"
NQS = require "nqserver"

local Advertiser = {}

--[[
ID is the identity of the device this Advertiser represents.
PORTFROM is the port from which we are advertising. It is also the port where we are listening for service invocations. Defaults to 1526.
PORTTO is the port to which we send advertisements. Defaults to 1525.
]]--
function Advertiser:new(id, portFrom, portTo)
    portFrom = portFrom or 1526
    self.portTo = portTo or 1525
    setmetatable(self, {})
    self.serviceList = {["id"] = id}
    self.functionMap = {}
    
    self.nqs = NQS:new(portFrom, function (message, ip, port)
        name = message[1]
        args = message[2]
        return {self.functionMap[name](unpack(args))}
    end)
    
    return self
end

--[[
Adds a service with the specified NAME, SUPC (superclass), DESC (description), and FUNC (function to call if the service is invoked).
]]--
function Advertiser:addService(name, supc, desc, func)
    self.serviceList[name] = {["s"] = supc, ["desc"] = desc}
    self.functionMap[name] = func
end

--[[
Removes the service with the specified name.
]]--
function Advertiser:rmService(name)
    self.serviceList[name] = nil
    self.functionMap[name] = nil
end

--[[
Sends one message advertising the registered services.
]]--
function Advertiser:advertise()
    msg = storm.mp.pack(self.serviceList)
    storm.net.sendto(self.nqs.socket, msg, "ff02::1", self.portTo)
end

--[[
Repeatedy advertises the registered services, waiting for the time duration DELAY between advertisements.
To stop the repeated advertisements, call storm.os.cancel on the "repeated" attribute of the advertiser.
]]--
function Advertiser:advertiseRepeatedly(delay)
    if self.repeated then
        storm.os.cancel(self.repeated)
    end
    self.repeated = storm.os.invokePeriodically(delay, function ()
        self:advertise()
    end)
end

--[[
Close this Advertiser's underlying sockets.
]]--
function Advertiser:close()
    if self.repeated then
        storm.os.cancel(self.repeated)
    end
    self.nqs:close()
end

return Advertiser
