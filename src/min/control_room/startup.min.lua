local a,b=pcall(function()require("core.app").start()end)if not a and tostring(b)~="Terminated"then print("CONTROL ROOM ERROR:")print(tostring(b))end
