local stringstream = require 'stringstream'

local Queue = {
    __call = function(self, ...) return table.remove(self, 1) end,
}
local function new_queue(...)
    return setmetatable({ ... }, Queue)
end

describe("stringstream.find", function()
    it("returns the right values", function()
        local chunks = new_queue("aaa", "bbb", "ccc", "   ")
        local ss = assert(stringstream.new(chunks, 3))
        assert.same({ 1, 1 }, { ss:find('a') })
        assert.same({ 1, 3 }, { ss:find('a+') })
        assert.same({ 2, 3 }, { ss:find('a+', 2) })
        assert.same({ 2, 3 }, { tostring(ss):find('a+', 2) })
        assert.is_nil(ss:find('%d'))
        assert.same({ 4, 6 }, { ss:find('b+') })
        assert.same({ 1, 9 }, { ss:find('%w*') })
        assert.same({ 1, 0 }, { ss:find('c*') })
        assert.same({ 1, 0 }, { tostring(ss):find('c*') })
        assert.same({ 10, 12 }, { ss:find('%s+') })
    end)

    it("loads contents on failure", function()
        local chunks = new_queue("aaa", "bbb", "ccc", "   ")
        local ss = assert(stringstream.new(chunks, 3))
        assert.same({ 7, 7 }, { ss:find('c') })
        assert.same({ 7, 9 }, { ss:find('c+') })
        assert.same({ 7, 7 }, { ss:find('c') })
    end)
end)

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
