# stringstream
An object that loads chunks of strings on demand compatible with a subset
of the [Lua string API](https://www.lua.org/manual/5.4/manual.html#6.4)
suitable for parsing. Compatible with Lua 5.1+

Useful for passing streams (e.g.: files) to parser functionality
that expects strings and use method notation (`text:match(...)`).

It is available as a [LuaRocks package](https://luarocks.org/modules/gilzoide/stringstream)
and has [online documentation](https://gilzoide.github.io/stringstream-lua/):

    $ luarocks install stringstream

Or just copy `stringstream.lua` into your Lua path and `require` it, the module has no dependencies.


## Using
```lua
local stringstream = require 'stringstream'

-- Streams may be created with callable objects (functions or tables/userdata
-- with __call metamethod) like the ones `load` expects, or file-like objects
-- that contain a `read` method, like open files.
local stream = assert(stringstream.new(io.stdin))

-- Alternatively, `stringstream.open(filename, ...)` may be used to open a file
-- by name in read mode and create a stringstream from it.
--
-- local stream = assert(stringstream.open("README.md"))

-- Now just call the supported string methods =D
while true do
    local token, advance = stream:match("(%S+)()")
    if not token then break end
    -- ... do something with token
    print('TOKEN', token)
    stream = stream:sub(advance)
end
```


## Supported methods and metamethods

- [__tostring](https://www.lua.org/manual/5.4/manual.html#2.4):
  Returns the current loaded content string.
  Be careful that it almost never reflects the entire content string.
- [__len](https://www.lua.org/manual/5.4/manual.html#2.4), [len](https://www.lua.org/manual/5.4/manual.html#pdf-string.len):
  Returns the length of the current loaded content.
  Be careful that it almost never reflects the entire contents length.
- [sub](https://www.lua.org/manual/5.4/manual.html#pdf-string.sub):
  If both `i` and `j` are passed, returns the string that starts at `i` and continues until `j`.
  If only `i` is passed, returns a new view into stream with starting index `i`. 
  Loads contents from stream if necessary.
  Negative indices are not supported.
- [find](https://www.lua.org/manual/5.4/manual.html#pdf-string.find):
  Try finding pattern on loaded contents. Upon failure or repetition items that
  match the whole string, loads new chunks and try again.
  Maximum number of extra bytes loaded is parameterizable upon creation.
  Negative indices are not supported.
- [match](https://www.lua.org/manual/5.4/manual.html#pdf-string.match):
  Try matching pattern on loaded contents. Upon failure or repetition items that
  match the whole string, loads new chunks and try again.
  Maximum number of extra bytes loaded is parameterizable upon creation.
  Negative indices are not supported.
- [gmatch](https://www.lua.org/manual/5.4/manual.html#pdf-string.gmatch):
  Returns an iterator function that, each time it is called, returns the next
  match from loaded contents. On iteration end or repetition items that match
  the whole string, loads new chunks and retry.
  Maximum number of extra bytes loaded is parameterizable upon creation.
  Negative indices are not supported.


## Running tests
Tests are run using [busted](https://olivinelabs.com/busted/):

    $ busted


## Documentation
The API is documented using [LDoc](https://github.com/stevedonovan/LDoc) and
is available at [github pages](https://gilzoide.github.io/stringstream-lua/).

To generate:

    $ ldoc .

## TODO

- Automated tests
- Remove commented `print` debug lines
- Add chunk caching configurations and document how memory is managed
- Check if should implement gsub and `__eq` with strings
- Check if should implement negative indices for streams that support seek operations (e.g.: files)
