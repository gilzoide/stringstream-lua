# stringstream (WIP)
An object that loads chunks of strings on demand compatible with a subset
of the [Lua string API](https://www.lua.org/manual/5.4/manual.html#6.4)
suitable for parsing.

This is meant to be used to pass streams (e.g.: files) to parser functionality
that expects strings and use method notation (`text:match(...)`).


## Supported methods and metamethods
- [__tostring](https://www.lua.org/manual/5.4/manual.html#2.4) metamethod:
  Returns the current loaded content string.
- [len](https://www.lua.org/manual/5.4/manual.html#pdf-string.len) and [__len](https://www.lua.org/manual/5.4/manual.html#2.4) metamethod:
  Returns the length of the current loaded content.
  This is probably only useful to check for end of contents with `#stream == 0`, as it almost never reflects the entire contents length.
- [sub](https://www.lua.org/manual/5.4/manual.html#pdf-string.sub):
  If both `i` and `j` are passed, returns the string that starts at `i` and continues until `j`.
  If only `i` is passed, returns a new view into stream with starting index `i`. 
  Loads contents from stream if necessary.
  Negative indices are not supported.
- [find](https://www.lua.org/manual/5.4/manual.html#pdf-string.find) (NYI):
  Try finding pattern on loaded contents. Upon failure or repetition items that
  match the whole string, loads new chunks and try again.
  Number of retries will be parameterizable upon creation.
  Negative indices are not supported.
- [match](https://www.lua.org/manual/5.4/manual.html#pdf-string.match) (NYI):
  Try matching pattern on loaded contents. Upon failure or repetition items that
  match the whole string, loads new chunks and try again.
  Number of retries will be parameterizable upon creation.
  Negative indices are not supported.
- [gmatch](https://www.lua.org/manual/5.4/manual.html#pdf-string.gmatch) (NYI):
  Returns an iterator function that, each time it is called, returns the next
  match from loaded contents. On iteration end or repetition items that match
  the whole string, loads new chunks and retry.
  Number of retries will be parameterizable upon creation.
  Negative indices are not supported.


## Running tests
Tests are run using [busted](https://olivinelabs.com/busted/):

    $ busted


## TODO
- Implement match
- Implement gmatch
- Add documentation
- Automated tests
- Remove commented `print` debug lines
- Add retry and chunk caching configurations
- Check if should implement gsub
- Check if should implement negative indices for streams that support seek operations (e.g.: files)
