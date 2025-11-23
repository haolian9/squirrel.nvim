some applications of nvim's treesitter API

## status
* just works

## prerequisites
* linux
* nvim 0.11.*
* haolian9/infra.nvim

## features & usage
* generating function doc (lua, go)
    * move cursor on a `function`, `:lua require'squirrel.docgen.lua'()`
* foldexpr (lua, python, zig, go, c, json)
    * `:lua require'squirrel.folding'.attach('lua')`
* jumping/selecting syntax objects (lua, zig)
    * `:lua require'squirrel.jumps'.attach('lua')`
    * more details see `jumps/{lua,zig}/init.lua`
* quick "import" (python, go)
    * `:lua require'squirrel.imports'()`
* incremental selection
    * `:lua require'squirrel.incsel'.n()` # general
    * `:lua require'squirrel.incsel'.m()` # lua only
* wrapping codes into block scope (lua, python, zig, c, go, sh)
    * select text then `:lua require'squirrel.veil'.cover('lua')`
* adding a few end pairs, imperfectly
* toggle python fstr
* sorting lua require statements
