-- This is meant to be run on the server Firestorm. No shield is required.

NQS = require "nqserver"
LED = require "led"

brd = LED:new("GP0")

server = NQS:new(50004, function (payload, address, ip)
    brd:flash()
    print("Received " .. payload.message)
    return {["message"] = payload.message .. " + goodbye."}
end)

sh = require "stormsh"
sh.start()
cord.enter_loop()
