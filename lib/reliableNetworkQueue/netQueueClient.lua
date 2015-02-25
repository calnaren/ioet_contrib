--[[

An abstraction for a reliable, ordered network queue for the client.

UDP is too unreliable for some applications. This library solves that
problem for a connection between a client and a server.

It repeatedly sends messages to improve reliability. It stores pending
messages in a queue, so the order in which the messages are sent on the
client is guaranteed to be the order in which they are received on the
server.

This is meant for client-side use, which means that all incoming messages
are expected to be responses to messages sent by this client.

]]--

local NQClient = {}
math = require("math")
math.randomseed(storm.os.now(storm.os.SHIFT_0))

empty = function () end

--[[ PORT is the port of the underlying UDP socket. ]]--
function NQClient:new(port)
    setmetatable(self, {})
    self.socket = storm.net.udpsocket(port, function (payload, ip, port)
        local unpacked = storm.mp.unpack(payload)
        if port == self.currPort and unpacked["_id"] == self.currID and self.pending then
            self.pending = false
            self.currSuccess(unpacked, ip, port)
        end
    end)
    self.currIP = nil
    self.currPort = nil
    self.pending = false
    self.ready = true
    self.pendingID = nil
    
    self.currSuccess = empty
    
    self.queue = {}
    self.front = 1
    self.back = 1
    
    self.currID = math.random(2000000000)
    
    self.send = send
    
    return self
end

--[[
     Pushes the provided message into the Network Queue. When all messages pushed earlier have been processed, this one is sent.
     MESSAGE is a table containing the message to be sent.
     ADDRESS is the destination IP Address.
     PORT is the destination port.
     TIMESTOTRY is the number of times to try and send the message before giving up. Defaults to 2000 tries.
     TIMEBETWEENTRIES is the amount of time to wait between attempts to send the message. Defaults to 15 ms.
     EACHTRY is the callback function that is executed every time the client attempts to send a UDP message.
     CALLBACK is the callback function to be called with the server's response when the transaction is completed. It takes three arguments: message, ip, and port, where message is the (unpacked) table containing the server's response and an additional _id field. If the message could not be sent, then the function is called with nil in all three arguments.
     ]]--
function NQClient:sendMessage(message, address, port, timesToTry, timeBetweenTries, eachTry, callback)
    callback = callback or empty
    eachTry = eachTry or empty
    -- Insert request into queue
    self.queue[self.back] = {["msg"] = message, ["addr"] = address, ["port"] = port, ["callback"] = callback, ["tcallback"] = eachTry, ["times"] = timesToTry, ["period"] = timeBetweenTries}
    self.back = self.back + 1
    
    self:processNextFromQueue()
end

--[[ You shouldn't need to call this function from outside of the class. ]]--
function NQClient:processNextFromQueue()
    if self.ready and not self.pending then
        if self.front == self.back then
            return -- nothing left to process in the queue
        end
    
        -- Dequeue request
        local req = self.queue[self.front]
        self.queue[self.front] = nil
        self.front = self.front + 1
        
        self.currIP = req.addr
        self.currPort = req.port
        local message = req.msg
        message._id = self.currID
        local msg = storm.mp.pack(message)
        
        self.currSuccess = req.callback
        local tryCallback = req.tcallback
        
        self.pending = true
        self.ready = false
        
        timesToTry = req.times or 1000
        timeBetween = req.period or 50 * storm.os.MILLISECOND
        
        cord.new(function ()
            local i = 0
            while self.pending and i < timesToTry do
                storm.net.sendto(self.socket, msg, self.currIP, self.currPort)
                tryCallback()
                cord.await(storm.os.invokeLater, timeBetween)
                i = i + 1
            end
            if self.pending then
                cord.await(storm.os.invokeLater, 500 * storm.os.MILLISECOND) -- wait a bit in case one of the last tries was heard
            end
            self.currSuccess = empty
            if self.pending then
                self.pending = false -- Give up
                req.callback(nil, nil, nil)
            end
            self.currID = math.random(2000000000)
            
            self.ready = true
            self:processNextFromQueue()
        end)
    end
end

--[[ Closes the underlying UDP socket. ]]--
function NQClient:close()
    storm.net.close(self.socket)
end

return NQClient
