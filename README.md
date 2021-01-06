# stringstream (WIP)
An object that loads chunks of strings on demand compatible with a subset
of the [Lua string API](https://www.lua.org/manual/5.4/manual.html#6.4)
suitable for parsing.

This is meant be used to pass streams (e.g.: files) to parser
functionality that expects strings and use method notation (`text:match(...)`).
