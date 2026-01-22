-- Utilities/Inheritance.lua
-- Lightweight inheritance helpers used by UI and utility modules.

---Sets table1 to index undefined properties in table2.
---@param table1 table
---@param table2 table
function Inherit(table1, table2)
    setmetatable(table1, {
        __index = table2.__index or table2,
        __newindex = table2.__newindex,
        __mode = table2.__mode,
        __call = table2.__call,
        __metatable = table2.__metatable,
        __tostring = table2.__tostring,
        __len = table2.__len,
        __pairs = table2.__pairs,
        __ipairs = table2.__ipairs,
        __name = table2.__name,

        __unm = table2.__unm,
        __add = table2.__add,
        __sub = table2.__sub,
        __mul = table2.__mul,
        __div = table2.__div,
        __idiv = table2.__idiv,
        __mod = table2.__mod,
        __pow = table2.__pow,
        __concat = table2.__concat,

        __band = table2.__band,
        __bor = table2.__bor,
        __bxor = table2.__bxor,
        __bnot = table2.__bnot,
        __shl = table2.__shl,
        __shr = table2.__shr,

        __eq = table2.__eq,
        __lt = table2.__lt,
        __le = table2.__le,
    })
end

---Sets table1 to index undefined properties in multiple parent tables.
---@param table1 table
---@param ... table
function InheritMultiple(table1, ...)
    local tbls = {...}

    setmetatable(table1, {
        __index = function(_, key)
            for _,tbl in ipairs(tbls) do
                if tbl[key] ~= nil then
                    return tbl[key]
                end
            end
        end
    })
end
