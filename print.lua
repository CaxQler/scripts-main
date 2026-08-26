-- [ 0x0bf43615 PROTECTED: print.lua ] --
local _chunks = {
    "6c6f63616c20706c6179657273203d2067616d653a476574536572766963652822506c617965727322290d0a0d0a0d0a7072696e74282248656c6c6f2c22202c706c61796572732e4c6f63616c506c617965722e4e616d6529",
};
local _data = table.concat(_chunks);
local function _dec(s)
    local r = ""
    for i = 1, #s, 2 do
        r = r .. string.char(tonumber(s:sub(i, i + 1), 16))
    end
    return r
end;
local code = _dec(_data);
local func, err = loadstring(code);
if func then
    return func()
else
    warn("0x0bf43615 Compile Error: " .. tostring(err))
end;
