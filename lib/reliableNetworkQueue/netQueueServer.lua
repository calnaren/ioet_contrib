--[[

An abstraction for a reliable, ordered network queue for the server.

This is meant for server-side use, which means that all messages sent
are responses to messages received from clients.

]]--

local NQServer = {}

--[[ PORT is the port of the underlying UDP socket.
RESPONSEGENERATOR is a function that produces a reponse for each message
received. It takes three arguments: the message (as a table) sent by the
client with an auxiliary _id field, the ip address from which the message
was received, and the port from which the message was received. It should
return a table containing the response to be sent to the client. ]]--
function NQServer:new(port, responseGenerator)
    setmetatable(self, {})
    self.currIDs = {}
    responseGenerator = responseGenerator or function () end
    self.socket = storm.net.udpsocket(port, function (payload, ip, port)
        local message = storm.mp.unpack(payload)
        local id = message["_id"]
        if self.currIDs[ip] == nil then
            self.currIDs[ip] = {}
        end
        if self.currIDs[ip][port] == nil then
            self.currIDs[ip][port] = {}
        end
        local response, toReply
        if self.currIDs[ip][port]["id"] ~= id then
            response = responseGenerator(message, ip, port)
            response["_id"] = id
            toReply = storm.mp.pack(response)
            self.currIDs[ip][port]["id"] = id
            self.currIDs[ip][port]["reply"] = toReply
        else
            toReply = self.currIDs[ip][port]["reply"]
        end
        storm.net.sendto(self.socket, toReply, ip, port)
    end)
    
    return self
end

--[[ Closes the underlying UDP socket. ]]--
function NQServer:close()
    storm.net.close(self.socket)
end

return NQServer
