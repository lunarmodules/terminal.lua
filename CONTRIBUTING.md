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

In this library we adhere to a rigorous standard of quality: every feature, function, or component added to the codebase is accompanied by comprehensive tests, where reasonable and applicable. This ensures reliability, maintainability, and robustness, and provides a safety net for future changes. Exceptions to this rule are documented and justified, so that our development process remains transparent.

Be sensible, write tests, increase coverage.


## Documentation

The documentation is generated from the repository. This is done using [ldoc](https://github.com/lunarmodules/LDoc).
The sources can be found in the ldoc configuration file; `config.ld`.

Please note that the generated documentation is only updated upon releasing. During development update comments, examples, etc. But do not commit any changes to the rendered documentation.

Use the `Makefile` to generate the documentation (`make docs`), and to clean it (`make clean`) in case you tested the generated docs but need to revert before comitting.



## Code style

todo
