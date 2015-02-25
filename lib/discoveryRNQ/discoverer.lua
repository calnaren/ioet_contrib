require "storm"
NQC = require "nqclient"

local Discoverer = {}

--[[
SERVICE_FOUND is a callback that is executed whenever a new service is discovered. Arguments: ip, port, device id, service name, and dict with description and superclass.
SERVICE_LOST is a callback that is executed whenever a service that was once discovered is no longer available. Arguments are the same as SERVICE_FOUND.
TIMEOUT is the the duration that a service should last when no advertisements are heard. If no advertisements are heard for a discovered service for this duration, the service will be removed from the discovered_services table and the SERVICE_LOST callback will be fired.
DPORT is the port where we listen for advertisements (defaults to 1525). IPORT is the port to which we send queued service invocations (defaults to 1526).
]]--
function Discoverer:new(service_found, service_lost, timeout, dport, iport)
    timeout = timeout or 300 * storm.os.SECOND
    dport = dport or 1525
    iport = iport or 1526
    self.dport = dport
    self.iport = iport
    setmetatable(self, {})
    
    -- Maps an ip address to a list of services
    self.discovered_services = {}
    self.timeouts = {}
    
    self.dsock = storm.net.udpsocket(dport, function (payload, ip, port)
        payload = storm.mp.unpack(payload)
        local old_payload = self.discovered_services[ip]
        local old_timeout = self.timeouts[ip]
        if old_timeout then
            storm.os.cancel(old_timeout)
        end
        local discovered_services = self.discovered_services
        local timeouts = self.timeouts
        self.timeouts[ip] = storm.os.invokeLater(timeout, function ()
            local toremove = discovered_services[ip]
            discovered_services[ip] = nil
            timeouts[ip] = nil
            for k, v in pairs(toremove) do
                if k ~= "id" then
                    service_lost(ip, port, toremove["id"], k, v)
                end
            end
        end)
        if old_payload then
            for k, v in pairs(old_payload) do
                if not payload[k] and k ~= "id" then
                    service_lost(ip, port, old_payload["id"], k, v)
                end
            end
            for k, v in pairs(payload) do
                if not old_payload[k] and k ~= "id" then
                    service_found(ip, port, payload["id"], k, v)
                end
            end
        else
            for k, v in pairs(payload) do
                if k ~= "id" then
                    service_found(ip, port, payload["id"], k, v)
                end
            end
        end
        self.discovered_services[ip] = payload
    end)
    
    self.nqc = NQC:new(iport)
    
    return self
end

--[[
Invokes a service with the given NAME and ARGS on the device with the specified IP address.
The service invocation will be queued and will only be executed after the previous service invocation made with this method completes.
TIMESTOTRY and TIMEBETWEENTRIES specify how many times and how often to attempt to send the message.
EACHTRY is a callback that is called every time the program attempts to send a message
CALLBACK is fired with an array-like table of return values from the service invocation. Arguments: retvals, ip, port. If the service invocation could not be performed, it is called with nil in all arguments.
]]--
function Discoverer:invoke(ip, name, args, timesToTry, timeBetweenTries, eachTry, callback)
    timesToTry = timesToTry or 500
    timeBetweenTries = timeBetweenTries or 50 * storm.os.MILLISECOND
    local msg = {name, args}
    self.nqc:sendMessage(msg, ip, self.iport, timesToTry, timeBetweenTries, eachTry, function (message, ip, port)
        message["_id"] = nil
        callback(message, ip, port)
    end)
end

--[[
The same as the invoke() method, except that the invocation is attempted immediately.
In other words, the discoverer will not queue this invocation and will not wait for the previous invocation to complete.
A new socket is created temporarily for the duration of the request. The port on which to create the socket must be specifed.
]]--
function Discoverer:invokeNow(ip, name, args, port, timesToTry, timeBetweenTries, eachTry, callback)
    timesToTry = timesToTry or 500
    timeBetweenTries = timeBetweenTries or 50 * storm.os.MILLISECOND
    local msg = {name, args}
    local temp_nqc = NQC:new(port)
    temp_nqc:sendMessage(msg, ip, self.iport, timesToTry, timeBetweenTries, eachTry, function (message, ip, port)
        temp_nqc:close()
        message["_id"] = nil
        callback(message, ip, port)
    end)
end

--[[
Resolves STR to services. STR can be a service name or a superclass name.
Returns a table mapping ip addresses to array-like tables of service names.
]]--
function Discoverer:resolve(str)
    local matches = {}
    local index
    for ip, servicetable in pairs(self.discovered_services) do
        index = 1
        for name, service in pairs(servicetable) do
            if name ~= "id" and (name == str or service["s"] == str) then
                if index == 1 then
                    matches[ip] = {name}
                else
                    matches[ip][index] = name
                end
                index = index + 1
            end
        end
    end
    return matches
end

--[[
Closes this Discoverer's underlying sockets and cancels pending timeouts.
]]--
function Discoverer:close()
    for ip, timeout in pairs(self.timeouts) do
        storm.os.cancel(timeout)
    end
    storm.net.close(self.dsock)
    self.nqc:close()
end

return Discoverer
