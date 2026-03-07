rocks_trees = {
    { name = [[user]],
         root    = home..[[/luarocks]],
    },
    { name = [[system]],
         root    = [[c:\users\vinit\documents\projects_vscode\cpp\dsa\web dev\terminal.lua\.hererocks\]],
    },
}
variables = {
    MSVCRT = 'm',   -- make MinGW use MSVCRT.DLL as runtime
    LUALIB = 'lua51.dll',
    CC = [[C:\MinGW\bin\gcc.exe]],
    MAKE = [[C:\MinGW\bin\mingw32-make.exe]],
    RC = [[C:\MinGW\bin\windres.exe]],
    LD = [[C:\MinGW\bin\gcc.exe]],
    AR = [[C:\MinGW\bin\ar.exe]],
    RANLIB = [[C:\MinGW\bin\ranlib.exe]],
}
verbose = false   -- set to 'true' to enable verbose output

cmake_generator = "MinGW Makefiles"
