if (test-path function:deactivate-lua) {
    deactivate-lua
}

function global:deactivate-lua () {
    if (test-path "C:\Users\vinit\Documents\Projects_VSCode\CPP\dsa\web dev\terminal.lua\.hererocks\bin\lua.exe") {
        $env:PATH = & "C:\Users\vinit\Documents\Projects_VSCode\CPP\dsa\web dev\terminal.lua\.hererocks\bin\lua.exe" "C:\Users\vinit\Documents\Projects_VSCode\CPP\dsa\web dev\terminal.lua\.hererocks\bin\get_deactivated_path.lua"
    }

    remove-item function:deactivate-lua
}

$env:PATH = "C:\Users\vinit\Documents\Projects_VSCode\CPP\dsa\web dev\terminal.lua\.hererocks\bin;" + $env:PATH
