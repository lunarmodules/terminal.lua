# Terminal.lua

A powerful cross-platform terminal manipulation library for Lua that works consistently across Windows, MacOS, and Unix systems.

[![Lua](https://img.shields.io/badge/Lua-5.1%2B-blue.svg)](https://lua.org)
[![LuaRocks](https://img.shields.io/badge/LuaRocks-terminal-brightgreen.svg)](https://luarocks.org/modules/terminal)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE.md)
[![Unix build](https://img.shields.io/github/actions/workflow/status/lunarmodules/terminal.lua/unix_build.yml?branch=main&label=Unix%20build&logo=linux)](https://github.com/lunarmodules/terminal.lua/actions/workflows/unix_build.yml)

## Features

- **Cross-platform compatibility** - Works seamlessly on Windows, MacOS, and Unix terminals
- **Cursor manipulation** - Control position, visibility, and shape
- **Text formatting** - Rich colors, styling, and text attributes
- **Terminal drawing** - Lines, boxes, and other visual elements
- **Progress indicators** - Customizable spinners, bars, and tickers
- **Input handling** - Raw keyboard input with ANSI sequence support
- **Screen manipulation** - Clearing, scrolling, and region control

## Installation

### Using LuaRocks

```bash
luarocks install terminal
```

### Manual Installation

1. Clone this repository:
```bash
git clone https://github.com/lunarmodules/terminal.lua.git
cd terminal.lua
```

2. Install using LuaRocks locally:
```bash
luarocks make
```

## Quick Start

```lua
local t = require("terminal")

-- Initialize the terminal
t.init()

-- Move cursor to position
t.cursor.position.set(10, 20)

-- Print colored text
t.text.color.set("green")
t.output.write("Hello, World!")
t.text.color.reset()

-- Create a spinner
local spinner = t.progress.spinner({
    sprites = t.progress.sprites.moon,
    row = 12,
    col = 5,
    textattr = {fg = "blue", brightness = "high"}
})

-- Use the spinner
for i = 1, 100 do
    spinner()
    t.sleep(0.1)
end
spinner(true) -- Mark as done

-- Clean up
t.shutdown()
```

## Documentation

Full documentation is available in the `/docs` directory. You can view it locally or at the [official documentation site](https://lunarmodules.github.io/terminal.lua/).

Key topics:
- [Introduction](https://lunarmodules.github.io/terminal.lua/topics/01-introduction.md.html)
- [TODO and Future Plans](https://lunarmodules.github.io/terminal.lua/topics/02-todo.md.html)
- [API Reference](https://lunarmodules.github.io/terminal.lua/)

## Examples

Check out the `/examples` directory for complete working examples:

- `progress.lua` - Demonstrates various progress indicators
- `input.lua` - Keyboard input handling
- `colors.lua` - Text coloring and styling
- `copas.lua` - Integration with Copas for asynchronous operation

## Project Structure

```
└── terminal.lua/
    ├── README.md                   # Project overview and documentation
    ├── CHANGELOG.md                # Version history and changes
    ├── config.ld                   # LDoc configuration file
    ├── CONTRIBUTING.md             # Contribution guidelines
    ├── LICENSE.md                  # MIT license details
    ├── Makefile                    # Build automation
    ├── terminal-scm-1.rockspec     # LuaRocks package specification
    ├── .busted                     # Busted test framework config
    ├── .editorconfig               # Editor formatting settings
    ├── .luacheckrc                 # Lua linter configuration
    ├── .luacov                     # Lua code coverage config
    ├── doc_topics/                 # Source for documentation pages
    │   ├── 01-introduction.md      # Introduction documentation
    │   ├── 02-todo.md              # Future development plans
    │   └── ldoc.css                # Documentation styling
    ├── docs/                       # Generated documentation
    │   ├── index.html              # Documentation homepage
    │   ├── classes/                # Class documentation
    │   ├── examples/               # Example documentation
    │   ├── modules/                # Module documentation
    │   └── topics/                 # Topic documentation
    ├── examples/                   # Example Lua scripts
    │   ├── async.lua               # Asynchronous operation demo
    │   ├── colors.lua              # Text coloring examples
    │   ├── headers.lua             # Header display examples
    │   ├── keymap.lua              # Keyboard mapping demo
    │   ├── progress.lua            # Progress indicators demo
    │   ├── sequence.lua            # Sequence class demo
    │   └── testscreen.lua          # Screen manipulation tests
    ├── experimental/               # Experimental features
    ├── spec/                       # Test specifications
    │   ├── 00-utils_spec.lua       # Utility function tests
    │   ├── 01-sequence_spec.lua    # Sequence class tests
    │   ├── 02-input_spec.lua       # Input handling tests
    │   ├── 02a-keymap_spec.lua     # Keyboard mapping tests
    │   ├── 03-clear_spec.lua       # Screen clearing tests
    │   ├── 04-scroll_spec.lua      # Scrolling tests
    │   ├── 05-scroll_stack_spec.lua# Scroll stack tests
    │   ├── 06-cursor_spec.lua      # Cursor operations tests
    │   ├── 07-color_spec.lua       # Color handling tests
    │   └── 08-attr_spec.lua        # Text attribute tests
    ├── src/                        # Source code directory
    │   └── terminal/               # Main terminal library
    │       ├── clear.lua           # Screen clearing functions
    │       ├── init.lua            # Library initialization
    │       ├── output.lua          # Terminal output handling
    │       ├── progress.lua        # Progress indicators
    │       ├── sequence.lua        # Sequence management
    │       ├── utils.lua           # Utility functions
    │       ├── cli/                # Command line interface
    │       ├── cursor/             # Cursor control modules
    │       ├── draw/               # Drawing functionality
    │       ├── input/              # Input handling
    │       ├── scroll/             # Scrolling functionality
    │       └── text/               # Text formatting and display
    └── .github/                    # GitHub-specific files
        └── workflows/              # CI/CD workflow definitions
            ├── lint.yml            # Linting workflow
            └── unix_build.yml      # Unix build & test workflow
```

### Key Components

- **src/terminal/** - The core library source code with submodules for different functionality areas
- **examples/** - Practical usage examples demonstrating library features
- **spec/** - Test suite for ensuring functionality and preventing regressions
- **docs/** - Generated documentation built from source code comments and doc_topics
- **doc_topics/** - Source markdown files for documentation sections

## Async Support

Terminal.lua works great with async frameworks like [Copas](https://github.com/keplerproject/copas). See `examples/copas.lua` for integration examples.

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

Current areas we're focusing on:
- Improving UTF-8 support and display width detection
- Adding more terminal widgets and interactive components
- Enhancing cross-platform testing
- Expanding documentation and examples

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details.

## Changelog & Versioning

See [CHANGELOG.md](CHANGELOG.md) for details on version history.

## Acknowledgments

- [LuaSystem](https://github.com/lunarmodules/luasystem) for the cross-platform foundation
- All contributors who have helped improve this library
