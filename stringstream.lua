--- An object that loads chunks of strings on demand compatible with a subset
-- of the string API suitable for parsing.

-- Lua 5.1+ compatibility
local unpack = table.unpack or unpack

--- Internal Stream state, caching chunks
local stream_state = {}
stream_state.__index = stream_state

function stream_state.new(read, ...)
    local state = setmetatable({
        read = read,
        contents = {},
        first_loaded_chunk = 1,
        last_loaded_chunk = 0,
        loaded_length = 0,
        read_args = { ... },
    }, stream_state)
    state:load_next()
    return state
end

function stream_state:calculate_chunk_index(from_chunk, starting_index)
    -- @warning: only call after checking `load_if_needed`
    local chunk_start = from_chunk
    local chunk = self.contents[chunk_start]
    while starting_index > #chunk do
        chunk_start = chunk_start + 1
        starting_index = starting_index - #chunk
        chunk = self.contents[chunk_start]
    end
    return chunk_start, starting_index
end

function stream_state:load_if_needed(from_chunk, starting_index)
    assert(from_chunk >= self.first_loaded_chunk, "Seeking stream backwards is not supported")
    -- TODO: after thorough testing, remove this next assertion
    assert(from_chunk <= self.last_loaded_chunk, "Invalid chunk number for stream, not loaded yet")
    
    -- unload chunks that are assumed to not be needed anymore
    self:unload_until(from_chunk)

    -- check how long loaded content is, to check if loading is necessary
    local loaded_length = self.loaded_length
    for i = self.first_loaded_chunk, from_chunk - 1 do
        loaded_length = loaded_length - #self.contents[i]
    end

    -- loads contents until `starting_index` is valid, returns `false` if not enough content is available
    while loaded_length < starting_index do
        local new_content = self:load_next()
        if not new_content then
            return false
        end
        loaded_length = loaded_length + #new_content
    end

    return true
end

function stream_state:load_next()
    local new_content = self.read(unpack(self.read_args))
    --print('   !!! loading', self.last_loaded_chunk + 1, string.format("%q", new_content))
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

--- Default chunk size of streams created with file objects.
--
-- Change this to configure defaults module-wise.
-- Default value is 1024.
stringstream.chunksize = 1024

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

--- Create a new stringstream from callable object or file-like object.
--
-- Both functions and tables or userdata with a `__call` metamethod are
-- accepted as callables. Just like `load`, each call must return a string that
-- concatenates with previous results and a return of an empty string, nil, or
-- no value signals the end of the stream. 
--
-- File-like objects are tables or userdata with a `read` method.
--
-- @tparam ?function|table|userdata callable_or_file  Callable or file-like object which chunks will be read from
-- @param ...  Arguments to be forwarded to the reading function. If `callable_or_file` is a file and no extra arguments are passed, `stringstream.chunksize` will be used
--
-- @return[1] stringstream object
-- @return[2] nil
-- @return[2] error message
function stringstream.new(callable_or_file, ...)
    local read, should_forward_default_chunksize
    if iscallable(callable_or_file) then
        read = callable_or_file
    else
        local read_type = type(callable_or_file)
        if read_type == 'table' or read_type == 'userdata' then
            if not callable_or_file.read then
                return nil, [[Argument is not a file-like object, no "read" method found]]
            end
            should_forward_default_chunksize = select('#', ...) == 0 and io.type(callable_or_file) == 'file'
            read = function(...) return callable_or_file:read(...) end
        else
            return nil, string.format([[Expected callable or file-like object, found %q]], read_type)
        end
    end
    local stream
    if should_forward_default_chunksize then
        stream = stream_state.new(read, stringstream.chunksize)
    else
        stream = stream_state.new(read, ...)
    end
    return wrap_stream(stream, 1, 1)
end

--- Creates a new stream from file.
--
-- Opens the file with `io.open` in read mode and forward parameters to
-- `stringstream.new`.
--
-- @see stringstream.new
--
-- @tparam string filename  Name of the file to open
-- @tparam ?string|number ...  Arguments to be forwarded to `file:read`
--
-- @return[1] stringstream object
-- @treturn[2] nil
-- @treturn[2] string  Error message
-- @treturn[2] number  Error code on `io.open` failure
function stringstream.open(filename, ...)
    local file, err, code = io.open(filename, 'r')
    if not file then
        return nil, err, code
    end
    return stringstream.new(file, ...)
end

--- Returns a substring or a new view into stream.
--
-- If both `i` and `j` are passed, returns the substring that starts at `i`
-- and continues until `j` or until the end of stream.
-- Otherwise, returns a new stringstream object with starting index `i`.
--
-- @raise If either `i` or `j` are non-positive, as reading from the end of
-- stream is not supported.
--
-- @tparam number i  Starting index
-- @tparam[opt] number j  Starting index
--
-- @treturn[1] stringstream If `j` is not passed and `i` is not past the end of the stream
-- @treturn[2] string Empty if `j` is not passed in and `i` is past the end of the stream
-- @treturn[3] string Substring if `j` is passed in
function stringstream:sub(i, j)
    assert(i and i > 0, "Calling stringstream.sub with non-positive index is not supported!")
    if not j then
        local starting_index = self.starting_index + i - 1
        if self.stream:load_if_needed(self.chunk, starting_index) then
            return wrap_stream(self.stream, self.stream:calculate_chunk_index(self.chunk, starting_index))
        else
            return ''
        end
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

--- Try finding `pattern` on loaded contents.
--
-- Upon failure or repetition items that match the whole loaded content,
-- loads a new chunk and retry.
--
-- @raise If `init` is a negative number.
--
-- @see string:find
--
-- @tparam string pattern  Pattern string to search
-- @tparam[opt] number init  Where to start the search from
-- @param[opt] plain  If truthy, turns off the pattern matching facilities
--
-- @treturn[1] number  Starting index of found pattern
-- @treturn[1] number  Ending index of found pattern
-- @treturn[1] ...  Aditional captures of found pattern
-- @treturn[2] fail  If pattern is not found
function stringstream:find(pattern, init, plain)
    init = init or 1
    assert(init >= 0, "Calling stringstream.find with negative index is not supported!")
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

--- Try matching `pattern` on loaded contents.
--
-- Uses `stringstream:find` for searching, so the same caveats apply.
--
-- @raise If `init` is a negative number.
--
-- @see string:match
-- @see stringstream:find
--
-- @tparam string pattern  Pattern string to search
-- @tparam[opt] number init  Where to start the search from
--
-- @treturn[1] ...  Captures of the found pattern
-- @treturn[2] string  The whole match, if pattern specifies no captures
-- @treturn[3] fail  If pattern is not found
function stringstream:match(pattern, init)
    assert((not init) or init >= 0, "Calling stringstream.match with negative index is not supported!")
    local find_results = { self:find(pattern, init, false) }
    if find_results[1] and not find_results[3] then
        return self:sub(find_results[1], find_results[2])
    else
        return unpack(find_results, 3)
    end
end

--- Returns an iterator function that, each time it is called, returns the next
-- match from loaded contents.
--
-- Uses `stringstream:find` for searching, so the same caveats apply.
--
-- @raise If `init` is a negative number.
--
-- @see string:gmatch
-- @see stringstream:match
--
-- @tparam string pattern  Pattern string to search
-- @tparam[opt] number init  Where to start the search from
--
-- @treturn function  Iterator function over matches
function stringstream:gmatch(pattern, init)
    assert((not init) or init >= 0, "Calling stringstream.gmatch with negative index is not supported!")
    -- Don't interpreted '^' as an anchor, just like `string.gmatch` does
    if pattern:sub(1, 1) == '^' then
        pattern = '%' .. pattern
    end
    local function iterate()
        local init = init
        while true do
            local find_results = { self:find(pattern, init, false) }
            if find_results[1] then
                --print('GMATCH', unpack(find_results))
                if not find_results[3] then
                    coroutine.yield(self:sub(find_results[1], find_results[2]))
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

--- Returns the current loaded content string.
--
-- Be careful that it almost never reflects the entire content string.
function stringstream:__tostring()
    return self.stream:string_from(self.chunk, self.starting_index)
end

--- Returns the current loaded content length.
--
-- Be careful that it almost never reflects the entire content length.
function stringstream:__len()
    return self.stream.loaded_length - (self.starting_index - 1)
end

--- Alias for `stringstream:__len`
-- @function stringstream.len

stringstream.__index = {
    sub = stringstream.sub,
    find = stringstream.find,
    match = stringstream.match,
    gmatch = stringstream.gmatch,
    len = stringstream.__len,
    __len = stringstream.__len,
}

--- Module version.
stringstream._VERSION = '0.1.1'

return stringstream
