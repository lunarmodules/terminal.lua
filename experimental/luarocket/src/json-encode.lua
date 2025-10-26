-- Code by Aapo Talvensari
-- https://github.com/bungle/lua-resty-prettycjson
local ok, cjson = pcall(require, "cjson.safe")
local enc = ok and cjson.encode or function() return nil, "Lua cJSON encoder not found" end
local cat = table.concat
local sub = string.sub
local rep = string.rep
-- @tparam table dt the data to encode
-- @tparam[opt="\n"] string lf the line feed separator
-- @tparam[opt="\t"] string id the indent characters
-- @tparam[opt=" "] string ac the array continuation characters
-- @tparam function ec the encoder function, defaults to CJSON encoder
-- @return string or nil+error
return function(dt, lf, id, ac, ec)
    local s, e = (ec or enc)(dt)
    if not s then return s, e end
    lf, id, ac = lf or "\n", id or "\t", ac or " "
    local i, j, k, n, r, p, q  = 1, 0, 0, #s, {}, nil, nil
    local al = sub(ac, -1) == "\n"
    for x = 1, n do
        local c = sub(s, x, x)
        if not q and (c == "{" or c == "[") then
            r[i] = p == ":" and cat{ c, lf } or cat{ rep(id, j), c, lf }
            j = j + 1
        elseif not q and (c == "}" or c == "]") then
            j = j - 1
            if p == "{" or p == "[" then
                i = i - 1
                r[i] = cat{ rep(id, j), p, c }
            else
                r[i] = cat{ lf, rep(id, j), c }
            end
        elseif not q and c == "," then
            r[i] = cat{ c, lf }
            k = -1
        elseif not q and c == ":" then
            r[i] = cat{ c, ac }
            if al then
                i = i + 1
                r[i] = rep(id, j)
            end
        else
            if c == '"' and p ~= "\\" then
                q = not q and true or nil
            end
            if j ~= k then
                r[i] = rep(id, j)
                i, k = i + 1, j
            end
            r[i] = c
        end
        p, i = c, i + 1
    end
    return cat(r)
end
