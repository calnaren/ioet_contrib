ACC = require "accel"

acc = ACC:new()

cord.new(function ()
    acc:init()
    while true do
        print(acc:get())
        cord.await(storm.os.invokeLater, 250 * storm.os.MILLISECOND)
    end
end)

cord.enter_loop()
