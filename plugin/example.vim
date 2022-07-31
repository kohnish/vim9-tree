vim9script

import "./tree.vim"

# Action to be performed when executing an object in the tree.
def Command_callback(id: number): void
    echom 'Calling object ' .. id .. '!'
    if id == 6
        b:integer_tree[6] = [7]
        b:integer_tree[7] = []
        b:nodes[7] = { "label": "Lazy Label 7" }
    	tree.Tree_update(b:tree, [6])
    	tree.Tree_set_collapsed_under_cursor(b:tree, 0)
    endif
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
    \   'collapsibleState': len(b:integer_tree[id]) > 0 ? 'collapsed' : 'none',
    \   'label': b:nodes[id]["label"]
    \ }
enddef

# The getChildren method can be called with no object argument, in that case it
# returns the root of the tree, or with one object as second argument, in that
# case it returns a list of objects that are children to the given object.
def Get_children(Render_children_nodes: func, ignition: dict<any>, object_id: number): void
    if !empty(ignition)
        b:nodes = {
            0: { "label": "Tree window for buffer: " .. ignition["bufnr"] },
            1: { "label": "Label 1" },
            2: { "label": "Label 2" },
            3: { "label": "Label 3" },
            4: { "label": "Label 4" },
            5: { "label": "Label 5" },
            6: { "label": "Label 6" },
            }
        b:integer_tree = {
            0: [1, 2],
            1: [3],
            2: [4, 5],
            3: [],
            4: [6],
            5: [],
            6: [],
            }
    endif
    var children = [0]
    if object_id != -1
        if has_key(b:integer_tree, object_id)
            children = b:integer_tree[object_id]
        endif
    endif
    Render_children_nodes(children)
enddef

# The getTreeItem returns the tree item representation of a given object.
def Get_tree_item(Append_node: func, object_id: number): void
    Append_node(Number_to_treeitem(object_id))
enddef

# Buffer local settings
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

    nnoremap <silent> <buffer> <Plug>(yggdrasil-toggle-node) <ScriptCmd>tree.Tree_set_collapsed_under_cursor(b:tree, -1)<CR>
    nnoremap <silent> <buffer> <Plug>(yggdrasil-open-node) <ScriptCmd>tree.Tree_set_collapsed_under_cursor(b:tree, 0)<CR>
    nnoremap <silent> <buffer> <Plug>(yggdrasil-close-node) <ScriptCmd>tree.Tree_set_collapsed_under_cursor(b:tree, 1)<CR>
    nnoremap <silent> <buffer> <Plug>(yggdrasil-execute-node) <ScriptCmd>tree.Tree_exec_node_under_cursor(b:tree)<CR>
    nnoremap <silent> <buffer> <Plug>(yggdrasil-wipe-tree) <ScriptCmd>tree.Tree_wipe(b:tree)<CR>

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
    syntax match YggdrasilNode            "\v^(\s|[▸▾•])*.*" contains=YggdrasilMarkLeaf,YggdrasilMarkCollapsed,YggdrasilMarkExpanded

    highlight def link YggdrasilMarkLeaf        Type
    highlight def link YggdrasilMarkExpanded    Type
    highlight def link YggdrasilMarkCollapsed   Macro
enddef

def Tree_window(): void
    var provider = {
        'getChildren': Get_children,
        'getTreeItem': Get_tree_item,
        }

    var orig_bufnr = bufnr('')
    topleft vnew
    b:tree = tree.New_tree(provider, {"bufnr": orig_bufnr})
    augroup vim_yggdrasil
        autocmd!
        autocmd FileType yggdrasil Filetype_syntax() | Filetype_settings()
        autocmd BufEnter <buffer> tree.Write_tree(b:tree)
    augroup END

    setlocal filetype=yggdrasil

    tree.Tree_update(b:tree, [])
enddef

command Vim9TreeWindow Tree_window()
