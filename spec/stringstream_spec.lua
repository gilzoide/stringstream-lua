local stringstream = require 'stringstream'

local function new_queue(...)
    local t = { ... }
    t.__call = table.remove
    return setmetatable(t, t)
end


describe("Calling with file", function()
    it("reads the entire file until completion", function()
        local ss = assert(stringstream.open("stringstream.lua", 42))
        local contents = ''
        repeat
            contents = contents .. ss:sub(1, 10)
            ss = ss:sub(11)
        until #ss <= 0
        local whole_contents = assert(io.open("stringstream.lua")):read('*a')
        assert.same(whole_contents, contents)
    end)
end)
