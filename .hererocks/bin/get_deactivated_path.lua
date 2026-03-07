local path = os.getenv("PATH")
local dir_sep = package.config:sub(1, 1)
local path_sep = dir_sep == "\\" and ";" or ":"
local hererocks_path = "C:\\Users\\vinit\\Documents\\Projects_VSCode\\CPP\\dsa\\web dev\\terminal.lua\\.hererocks" .. dir_sep .. "bin"
local new_path_parts = {}
local for_fish = arg[1] == "--fish"

if for_fish then
    io.stdout:write("set -gx PATH ")
end

for path_part in (path .. path_sep):gmatch("([^" .. path_sep .. "]*)" .. path_sep) do
    if path_part ~= hererocks_path then
        if for_fish then
            path_part = "'" .. path_part:gsub("'", [[''']]) .. "'"
        end

        table.insert(new_path_parts, path_part)
    end
end

io.stdout:write(table.concat(new_path_parts, for_fish and " " or path_sep))
