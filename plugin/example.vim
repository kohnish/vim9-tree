vim9script

import "tree.vim"

# Minimal example of tree data. The objects are integer numbers.
# Here the tree structure is implemented with a dictionary mapping parents to
# children.
var g_tree = {
\     0: [1, 2],
\     1: [3],
\     2: [4, 5],
\     3: [],
\     4: [6],
\     5: [],
\     6: [],
\ }

# Action to be performed when executing an object in the tree.
def Command_callback(id: number): void
    echom 'Calling object ' .. id .. '!'
enddef

# Auxiliary function to map each object to its parent in the tree.
# return type????
def Number_to_parent(id: number): dict<any>
    for [parent, children] in items(g_tree)
        if index(children, id) > 0
            return parent
        endif
    endfor
    return {}
enddef

# Auxiliary function to produce a minimal tree item representation for a given
# object (i.e. a given integer number).
#
# The four mandatory fields for the tree item representation are:
#  * id: unique string identifier for the node in the tree
#  * collapsibleState: string value, equal to:
#     + 'collapsed' for an inner node initially collapsed
#     + 'expanded' for an inner node initially expanded
#     + 'none' for a leaf node that cannot be expanded nor collapsed
#  * command: function object that takes no arguments, it runs when a node is
#    executed by the user
#  * labe string representing the node in the view
def Number_to_treeitem(id: number): dict<any>
    return {
    \   'id': string(id),
    \   'command': () => Command_callback(id),
    \   'collapsibleState': len(g_tree[id]) > 0 ? 'collapsed' : 'none',
    \   'label': 'Label of node ' .. id,
    \ }
enddef

# The getChildren method can be called with no object argument, in that case it
# returns the root of the tree, or with one object as second argument, in that
# case it returns a list of objects that are children to the given object.
def GetChildren(Callback: func, args: list<any>): void
    var children = [0]
    if len(args) > 0
        if has_key(g_tree, args[0])
            children = g_tree[args[0]]
        else
            Callback('failure')
        endif
    endif
    Callback('success', children)
enddef

# The getParent method returns the parent of a given object.
def GetParent(Callback: func, object: number): void
    Callback('success', Number_to_parent(object))
enddef

# The getTreeItem returns the tree item representation of a given object.
def GetTreeItem(Callback: func, object: number): void
    Callback('success', Number_to_treeitem(object))
enddef

def MutateNode(mode: string): void
    if mode == "toggle"
        tree.Tree_set_collapsed_under_cursor(b:handle, -1)
    elseif mode == "wipe"
        tree.Tree_wipe(b:handle)
    elseif mode == "open"
        tree.Tree_set_collapsed_under_cursor(b:handle, 0)
    elseif mode == "close"
        tree.Tree_set_collapsed_under_cursor(b:handle, 1)
    elseif mode == "exec"
        tree.Tree_exec_node_under_cursor(b:handle)
    endif
enddef

command -nargs=1 Vim9TreeMutateNode MutateNode(<f-args>)

# Apply local settings to an Yggdrasil buffer
def Filetype_settings(): void 
    setlocal bufhidden=wipe
    setlocal buftype=nofile
    setlocal foldcolumn=0
    setlocal foldmethod=manual
    setlocal nobuflisted
    setlocal nofoldenable
    setlocal nolist
    setlocal nomodifiable
    setlocal nonumber
    setlocal norelativenumber
    setlocal nospell
    setlocal noswapfile
    setlocal nowrap

    nnoremap <silent> <buffer> <Plug>(yggdrasil-toggle-node) :Vim9TreeMutateNode toggle<CR>
    nnoremap <silent> <buffer> <Plug>(yggdrasil-open-node) :Vim9TreeMutateNode open<CR>
    nnoremap <silent> <buffer> <Plug>(yggdrasil-close-node) :Vim9TreeMutateNode close<CR>
    nnoremap <silent> <buffer> <Plug>(ggdrasil-execute-node) :Vim9TreeMutateNode exec<CR>
    nnoremap <silent> <buffer> <Plug>(yggdrasil-wipe-tree) :Vim9TreeMutateNode wipe<CR>

    if !exists('g:yggdrasil_no_default_maps')
        nmap <silent> <buffer> o    <Plug>(yggdrasil-toggle-node)
        nmap <silent> <buffer> <CR> <Plug>(yggdrasil-execute-node)
        nmap <silent> <buffer> q    <Plug>(yggdrasil-wipe-tree)
    endif
enddef

def Filetype_syntax(): void
    syntax clear
    syntax match YggdrasilMarkLeaf        "•" contained
    syntax match YggdrasilMarkCollapsed   "▸" contained
    syntax match YggdrasilMarkExpanded    "▾" contained
    syntax match YggdrasilNode            "\v^(\s|[▸▾•])*.*"
    \      contains=YggdrasilMarkLeaf,YggdrasilMarkCollapsed,YggdrasilMarkExpanded

    highlight def link YggdrasilMarkLeaf        Type
    highlight def link YggdrasilMarkExpanded    Type
    highlight def link YggdrasilMarkCollapsed   Macro
enddef


def Window(): void
    var provider = {
    \ 'getChildren': GetChildren,
    \ 'getParent': GetParent,
    \ 'getTreeItem': GetTreeItem,
    \ }

    topleft vnew
    b:handle = tree.New(provider)
    augroup vim_yggdrasil
        autocmd!
        autocmd FileType yggdrasil Filetype_syntax() | Filetype_settings()
        autocmd BufEnter <buffer> tree.Render(b:handle)
    augroup END

    setlocal filetype=yggdrasil

    b:handle.update(b:handle, [])
enddef

command Vim9TreeWindow Window()
