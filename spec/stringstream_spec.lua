local stringstream = require 'stringstream'

local Queue = {
    __call = function(self, ...) return table.remove(self, 1) end,
}
local function new_queue(...)
    return setmetatable({ ... }, Queue)
end
local function test_queue()
    return new_queue("aaa", "bbb", "ccc", "   ", "\n")
end

describe("stringstream.sub", function()
    it("errors if negative indexing is used", function()
        local ss = assert(stringstream.new(test_queue()))
        assert.has.errors(function() ss:sub(-1) end)
        assert.has.errors(function() ss:sub(1, -1) end)
    end)

    it("returns empty string after reading ends", function()
        local ss = assert(stringstream.new(test_queue()))
        assert.same('', ss:sub(9999))
    end)
end)

describe("stringstream.find", function()
    it("errors if negative indexing is used", function()
        local ss = assert(stringstream.new(test_queue()))
        assert.has.errors(function() ss:find('a', -1) end)
    end)

    it("returns the right values", function()
        local ss = assert(stringstream.new(test_queue()))
        assert.same({ 1, 1 }, { ss:find('a') })
        assert.same({ 1, 3 }, { ss:find('a+') })
        assert.is_nil(ss:find('a+', 1, true))
        assert.same({ 2, 3 }, { ss:find('a+', 2) })
        assert.same({ 1, 3, 'aaa' }, { ss:find('(a+)') })
        assert.is_nil(ss:find('!'))
        assert.same({ 1, 0 }, { ss:find('b*') })
    end)

    it("loads chunks on failure", function()
        local ss = assert(stringstream.new(test_queue()))
        assert.is_nil(ss:find('%d'))
        assert.same({ 4, 6 }, { ss:find('b+') })
        assert.same({ 7, 9, 'cc' }, { ss:find('c(c*)') })
    end)

    it("loads additional chunks if match may be longer than loaded contents", function()
        local ss = assert(stringstream.new(test_queue()))
        assert.same({ 1, 9 }, { ss:find('%w*') })
    end)

    it("returns match in end of contents", function()
        local ss = assert(stringstream.new(test_queue()))
        assert.same({ 10, 13 }, { ss:find('%s+') })
    end)

    it("preserves end of string anchors, although this loads all content", function()
        local ss = assert(stringstream.new(test_queue()))
        assert.is_nil(ss:find('a+$'))
    end)
end)

describe("stringstream.gmatch", function()
    it("doesn't interpret a leading '^' as anchor", function()
        local ss = assert(stringstream.new(test_queue()))
        local iterator = ss:gmatch("^a")
        assert.is_nil(iterator())
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
