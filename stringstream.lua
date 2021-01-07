-- Lua 5.1+ compatibility
local unpack = table.unpack or unpack

--- Default chunk size
local DEFAULT_CHUNKSIZE = 1024

--- Internal Stream state, caching chunks
local stream_state = {}
stream_state.__index = stream_state

function stream_state.new(read, chunksize)
    local state = setmetatable({
        read = read,
        chunksize = chunksize or DEFAULT_CHUNKSIZE,
        contents = {},
        first_loaded_chunk = 1,
        last_loaded_chunk = 0,
        loaded_length = 0,
    }, stream_state)
    state:load_next()
    return state
end

function stream_state:index_to_chunk(starting_index)
    return math.floor((starting_index - 1) / self.chunksize)
end

function stream_state:recalculate_chunk_index(chunk, starting_index)
    local chunk_inc = self:index_to_chunk(starting_index)
    return chunk + chunk_inc, starting_index - (chunk_inc * self.chunksize)
end

function stream_state:load_if_needed(from_chunk, starting_index)
    assert(from_chunk >= self.first_loaded_chunk, "Seeking stream backwards is not supported")
    
    -- unload chunks that are assumed to not be needed anymore
    self:unload_until(from_chunk)

    -- load missing chunks, if any
    local chunk = from_chunk + self:index_to_chunk(starting_index)
    for i = from_chunk + 1, chunk do
        if not self.contents[i] then
            local new_content = self.read(self.chunksize)
            if not new_content or #new_content <= 0 then
                --print('  !!! loading', i, 'aborted')
                break
            end
            --print('  !!! loading', i, string.format("%q", new_content))
            self.contents[i] = new_content
            self.loaded_length = self.loaded_length + #new_content
            self.last_loaded_chunk = i
        end
    end
    --print('  !!! loaded', self.first_loaded_chunk .. ' ~ ' .. self.last_loaded_chunk)
    return self.contents[chunk]
end

function stream_state:load_next()
    local new_content = self.read(self.chunksize)
    if not new_content or #new_content <= 0 then
        return nil
    end
    self.last_loaded_chunk = self.last_loaded_chunk + 1
    self.contents[self.last_loaded_chunk] = new_content
    self.loaded_length = self.loaded_length + #new_content
    return new_content
end

function stream_state:unload_until(chunk)
    for i = self.first_loaded_chunk, chunk - 2 do
        --print('  !!! unloading', i)
        self.loaded_length = self.loaded_length - #self.contents[i]
        self.contents[i] = nil
        self.first_loaded_chunk = i + 1
    end
end

function stream_state:string_from(chunk, starting_index, end_index)
    assert(chunk >= self.first_loaded_chunk, "Trying to access unloaded chunks")
    local content = table.concat(self.contents, '', chunk, self.last_loaded_chunk)
    --print('  !!! STRING', chunk, starting_index, end_index, self.contents[chunk] ~= nil, self.contents[self.last_loaded_chunk] ~= nil)
    return content:sub(starting_index, end_index)
end

function stream_state:__len()
    return self.loaded_length
end

function stream_state:__tostring()
    return self:string_from(self.first_loaded_chunk, 1)
end

--- String Stream module
local stringstream = {}

stringstream.chunksize = DEFAULT_CHUNKSIZE

local function iscallable(v)
    if type(v) == 'function' then
        return true
    else
        local mt = getmetatable(v)
        return mt and mt.__call
    end
end

local function wrap_stream(stream, chunk, starting_index)
    return setmetatable({
        stream = stream,
        chunk = chunk or stream.first_loaded_chunk,
        starting_index = starting_index or 1,
    }, stringstream)
end

function stringstream.new(read_or_file, chunksize)
    local read
    if iscallable(read_or_file) then
        read = read_or_file
    else
        local read_type = type(read_or_file)
        if read_type == 'table' or read_type == 'userdata' then
            if not read_or_file.read then
                return nil, [[Argument is not a file-like object, no "read" method found]]
            end
            read = function(...) return read_or_file:read(...) end
        else
            return nil, string.format([[Expected callable or file-like object, found %q]], read_type)
        end
    end
    local stream = stream_state.new(read, chunksize or stringstream.chunksize)
    return wrap_stream(stream, 1, 1)
end

function stringstream.open(filename, chunksize)
    local file, err, code = io.open(filename)
    if not file then
        return nil, err, code
    end
    return stringstream.new(file, chunksize)
end

function stringstream:sub(i, j)
    assert(i > 0, "Calling stringstream.sub with non-positive index is not supported!")
    if not j then
        local starting_index = self.starting_index + i - 1
        self.stream:load_if_needed(self.chunk, starting_index)
        return wrap_stream(self.stream, self.stream:recalculate_chunk_index(self.chunk, starting_index))
    else
        assert(j > 0, "Calling stringstream.sub with negative index is not supported!")
        if j < i then
            return ''
        end
        local starting_index = self.starting_index + i - 1
        local ending_index = self.starting_index + j - 1
        self.stream:load_if_needed(self.chunk, ending_index)
        return self.stream:string_from(self.chunk, starting_index, ending_index)
    end
end

function stringstream:find(pattern, init, plain)
    init = init or 1
    assert(init > 0, "Calling stringstream.find with non-positive index is not supported!")
    local stream, chunk, starting_index = self.stream, self.chunk, self.starting_index
    stream:load_if_needed(chunk, starting_index + init - 1)
    while true do
        local text = stream:string_from(chunk, starting_index)
        local results = { text:find(pattern, init, plain) }
        if results[1] and results[2] < #text then
            return unpack(results)

            -- TODO: check if `init` may be updated with `results[1]` in case a
            -- match was found, but may be longer, to reduce search space
            -- (check if there are cases where this would return wrong results)
        end
        if not stream:load_next() then
            return unpack(results)
        end
    end
end

function stringstream:match(pattern, init)
    assert((not init) or init > 0, "Calling stringstream.match with non-positive index is not supported!")
    local find_results = { self:find(pattern, init, false) }
    if find_results[1] and not find_results[3] then
        return self:sub(find_results[1], find_results[2])
    else
        return unpack(find_results, 3)
    end
end

function stringstream:gmatch(pattern, init)
    assert((not init) or init > 0, "Calling stringstream.gmatch with non-positive index is not supported!")
    local function iterate()
        local init = init
        while true do
            local find_results = { self:find(pattern, init, false) }
            if find_results[1] then
                --print('GMATCH', unpack(find_results))
                if not find_results[3] then
                    coroutine.yield(self.sub(find_results[1], find_results[2]))
                else
                    coroutine.yield(unpack(find_results, 3))
                end
                init = find_results[2] + 1
            else
                return nil
            end
        end
    end
    return coroutine.wrap(iterate)
end

function stringstream:__tostring()
    return self.stream:string_from(self.chunk, self.starting_index)
end

function stringstream:__len()
    return self.stream.loaded_length - (self.starting_index - 1)
end

stringstream.__index = {
    sub = stringstream.sub,
    find = stringstream.find,
    match = stringstream.match,
    gmatch = stringstream.gmatch,
    len = stringstream.__len,
    __len = stringstream.__len,
}

stringstream._VERSION = '0.1.0'

return stringstream
