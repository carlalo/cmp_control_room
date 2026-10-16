
local ok, err = pcall(function()
    require("core.app").start()
end)

if not ok and tostring(err) ~= "Terminated" then
    print("CONTROL ROOM ERROR:")
    print(tostring(err))
end
