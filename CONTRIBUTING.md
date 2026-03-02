# CONTRIBUTING

## Getting started

The `Makefile` contains all the major operations. The default make target will display some help information about available targets.

The `Makefile` assumes that no sudo-isms are required to do its work. If there are permission issues then try to move LuaRocks to the local tree.

LuaRocks has 2 trees; `system` tree (typically requires sudo) and `user` tree (user local) where it installs modules. To ensure using the `user` tree only, set it as the default:

    luarocks config local_by_default true

Optionally erase everything from the `system` tree (`sudo` might be required):

    sudo luarocks purge --tree=system

This ensures that anything in the system tree doesn't take precedence over the `user` tree contents and causes unexpected results.


## Commiting code

### Commit atomicity

When submitting patches, it is important that you organize your commits in logical units of work. You are free to propose a patch with one or many commits, as long as their atomicity is respected. This means that no unrelated changes should be included in a commit.

For example: you are writing a patch to fix a bug, but in your endeavour, you spot another bug. Do not fix both bugs in the same commit! Finish your work on the initial bug, propose your patch, and come back to the second bug later on. This is also valid for unrelated style fixes, refactors, etc...

You should use your best judgment when facing such decisions. A good approach for this is to put yourself in the shoes of the person who will review your patch: will they understand your changes and reasoning just by reading your commit history? Will they find unrelated changes in a particular commit? They shouldn't!

Writing meaningful commit messages that follow our commit message format will also help you respect this mantra (see the below section).


### Commit messages

To maintain a healthy Git history, we ask of you that you write your commit messages as follows:

- The tense of your message must be present
- Your message must be prefixed by a type, and a scope
- The header of your message should not be longer than 50 characters
- A blank line should be included between the header and the body
- The body of your message should not contain lines longer than 72 characters

We strive to adapt the [conventional-commits](https://www.conventionalcommits.org/en/v1.0.0/) format.

Here is a template of what your commit message should look like:

    <type>(<scope>): <subject>
    <BLANK LINE>
    <body>
    <BLANK LINE>
    <footer>


#### Commit scopes

The scope is the part of the codebase that is affected by your change. Choosing it is at your discretion, check the commit history for common ones.


#### Commit types

The type of your commit indicates what type of change this commit is about. The accepted types are:

- `feat`: A new feature
- `fix`: A bug fix
- `hotfix`: An urgent bug fix during a release process
- `tests`: A change that is purely related to the test suite only (fixing a test, adding a test, improving its reliability, etc...)
- `docs`: Changes to the markdown files, or doc-comments in the code (see [Documentation](#documentation)).
- `style`: Changes that do not affect the meaning of the code (white-space trimming, formatting, etc...)
- `perf`: A code change that significantly improves performance
- `refactor`: A code change that neither fixes a bug nor adds a feature
- `chore`: Maintenance changes related to code cleaning that isn't considered part of a refactor, build process updates, dependency bumps, or auxiliary tools and libraries updates (LuaRocks, GitHub Actions, etc...).


## Testing

Testing is done using the busted test framework, LuaCheck for linting, and LuaCov for coverage.

Use `make test` and `make lint` to run the tests. Coverage information will be in the file `luacov.report.out`.

When writing tests, use the helpers (in `./spec/helpers.lua`) to ensure proper isolation and for handling generic mocking (mostly in and output). This is required over manually adding mocks etc in test files, any deviations should be clearly explained and documented.

In this library we adhere to a rigorous standard of quality: every feature, function, or component added to the codebase is accompanied by comprehensive tests, where reasonable and applicable. This ensures reliability, maintainability, and robustness, and provides a safety net for future changes. Exceptions to this rule are documented and justified, so that our development process remains transparent.

Be sensible, write tests, increase coverage.


## Documentation

The documentation is generated from the repository. This is done using [ldoc](https://github.com/lunarmodules/LDoc).
The sources can be found in the ldoc configuration file; `config.ld`.

Please note that the generated documentation is only updated upon releasing. During development update comments, examples, etc. But do not commit any changes to the rendered documentation.

Use the `Makefile` to generate the documentation (`make docs`), and to clean it (`make clean`) in case you tested the generated docs but need to revert before comitting.



## Code style

In order to ensure a healthy and consistent codebase, we ask of you that you
respect the adopted code style. This section contains a non-exhaustive list
of preferred styles for writing Lua. It is opinionated but common.

Basic rules for indentation etc can be found in `.luacheckrc` and `.editorconfig`.

When you are unsure about the style to adopt, please browse other parts of the
codebase to find a similar case, and stay consistent with it.

You might also notice places in the codebase where the described style is not
respected. This is due to legacy code. **Contributions to update the code to
the recommended style are welcome!**


### Table of Contents - Code style

- [Modules](#modules)
- [Variables](#variables)
- [Tables](#tables)
- [Strings](#strings)
- [Functions](#functions)
- [Conditional expressions](#conditional-expressions)


### Modules

When writing a module (a Lua file), separate logical blocks of code with
**three** blank lines:

```lua
local foo = require "some_module.foo"



local _M = {}



function _M.bar()
  -- do thing...
end



function _M.baz()
  -- do thing...
end



return _M
```


### Variables

When naming a variable or function, **do** use snake_case:

```lua
-- bad
local myString = "hello world"

-- good
local my_string = "hello world"
```

When assigning a constant variable, **do** give it an uppercase name:

```lua
-- bad
local max_len = 100

-- good
local MAX_LEN = 100
```


### Tables

Use the constructor syntax, and **do** include a trailing comma:

```lua
-- bad
local t = {}
t.foo = "hello"
t.bar = "world"

-- good
local t = {
  foo = "hello",
  bar = "world", -- note the trailing comma
}
```

On single-line constructors, **do** include spaces around curly-braces and
assignments:

```lua
-- bad
local t = {foo="hello",bar="world"}

-- good
local t = { foo = "hello", bar = "world" }
```

Prefer `ipairs()` to `for` loop when iterating an array,
which gives us more readability:

```lua
-- bad
for i = 1, #t do
  ...
end

-- good
for _, v in ipairs(t) do
  ...
end
```


### Strings

**Do** favor the use of double quotes in all Lua code:

```lua
-- bad
local str = 'hello'

-- good
local str = "hello"
```

If a string contains double quotes, **do** favor single quotes:

```lua
-- bad
local str = "message: \"hello\""

-- good
local str = 'message: "hello"'
```

When using the concatenation operator, **do** insert spaces around it:

```lua
-- bad
local str = "hello ".."world"

-- good
local str = "hello " .. "world"
```

If a string is too long, **do** break it into multiple lines,
and join them with the concatenation operator:

```lua
-- bad
local str = "It is a very very very long string, that should be broken into multiple lines."

-- good
local str = "It is a very very very long string, " ..
            "that should be broken into multiple lines."
```


### Functions

Prefer the function syntax over variable syntax:

```lua
-- bad
local foo = function()

end

-- good
local function foo()

end
```

Perform validation early and return as early as possible:

```lua
-- bad
local function check_name(name)
  local valid = #name > 3
  valid = valid and #name < 30

  -- other validations

  return valid
end

-- good
local function check_name(name)
  if #name <= 3 or #name >= 30 then
    return false
  end

  -- other validations

  return true
end
```

Prefer if-then-error over assertions:

```lua
-- bad
local function some_func(name)
  -- string concatenation happens on good- and failure-case
  assert(type(name) == "string", "expected name to be a string, got " .. type(name))

  -- do work
end

-- good
local function some_func(name)
  if type(name) ~= "string" then
    error("expected name to be a string, got " .. type(name))
  end

  -- do work
end
```

Follow the return values conventions: Lua supports multiple return values, and
by convention, handles recoverable errors by returning `nil` plus a `string`
describing the error:

```lua
-- bad
local function check()
  local ok, err = do_thing()
  if not ok then
    return false, { message = err }
  end

  return true
end

-- good
local function check()
  local ok, err = do_thing()
  if not ok then
    return nil, "could not do thing: " .. err
  end

  return true
end
```

When a function call makes a line go over 100 characters, **do** align the
overflowing arguments to the first one:

```lua
-- bad
local str = string.format("SELECT * FROM users WHERE first_name = '%s'", first_name)

-- good
local str = string.format("SELECT * FROM users WHERE first_name = '%s'",
                          first_name)
```


### Conditional expressions

Avoid writing 1-line conditions, **do** indent the child branch:

```lua
-- bad
if err then return nil, err end

-- good
if err then
  return nil, err
end
```

When testing the assignment of a value, **do** use shortcuts, unless you
care about the difference between `nil` and `false`:

```lua
-- bad
if str ~= nil then

end

-- good
if str then

end
```

When creating multiple branches that span multiple lines, **do** include a
blank line above the `elseif` and `else` statements:

```lua
-- bad
if foo then
  do_stuff()
  keep_doing_stuff()
elseif bar then
  do_other_stuff()
  keep_doing_other_stuff()
else
  error()
end

-- good
if thing then
  do_stuff()
  keep_doing_stuff()

elseif bar then
  do_other_stuff()
  keep_doing_other_stuff()

else
  error()
end
```

For one-line blocks, blank lines are not necessary:

```lua
--- good
if foo then
  do_stuff()
else
  error("failed!")
end
```

Note in the correct "long" example that if some branches are long, then all
branches are created with the preceding blank line (including the one-liner
`else` case).

When a branch returns, **do not** create subsequent branches, but write the
rest of your logic on the parent branch:

```lua
-- bad
if not str then
  return nil, "bad value"
else
  do_thing(str)
end

-- good
if not str then
  return nil, "bad value"
end

do_thing(str)
```

When assigning a value or returning from a function, **do** use ternaries if
it makes the code more readable:

```lua
-- bad
local foo
if bar then
  foo = "hello"

else
  foo = "world"
end

-- good
local foo = bar and "hello" or "world"
```

When an expression makes a line longer than 100 characters, **do** align the
expression on the following lines:

```lua
-- bad
if thing_one < 1 and long_and_complicated_function(arg1, arg2) < 10 or thing_two > 10 then
  do_thing(str)
end

-- good
if thing_one < 1 and long_and_complicated_function(arg1, arg2) < 10
   or thing_two > 10
then
  do_thing(str)
end
```
