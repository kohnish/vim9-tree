vim9script

var g_tree_top = {}

# Callback to retrieve the tree item representation of an object.
def Node_get_tree_item_cb(node: dict<any>, object: number, status: string, tree_item: dict<any>): void
    if status ==? 'success'
        var new_node = Node_new(node.tree, object, tree_item, node)
        add(node.children, new_node)
        Tree_render(new_node.tree)
    endif
enddef

# Callback to retrieve the children objects of a node.
def Node_get_children_cb(node: dict<any>, status: string, childObjectList: list<any>): void
    for childObject in childObjectList
        node.tree.provider.getTreeItem((result: string, tree_item: dict<any>) => Node_get_tree_item_cb(node, childObject, result, tree_item), childObject)
    endfor
enddef

# Set the node to be collapsed or expanded.
# When {collapsed} evaluates to 0 the node is expanded, when it is 1 the node is
# collapsed, when it is equal to -1 the node is toggled (it is expanded if it
# was collapsed, and vice versa).
def Node_set_collapsed(self: dict<any>, collapsed: number): void
    self.collapsed = collapsed < 0 ? !self.collapsed : !!collapsed
enddef

# Given a funcref {Condition}, return a list of all nodes in the subtree of
# {node} for which {Condition} evaluates to v:true.
def Search_subtree(node: dict<any>, Condition: func): list<any>
    if Condition(node)
        return [node]
    endif
    if len(node.children) < 1
        return []
    endif
    var result = []
    for child in node.children
        result = result + Search_subtree(child, Condition)
    endfor
    return result
enddef

# Execute the action associated to a node
def Node_exec(self: dict<any>): void
    if has_key(self.tree_item, 'command')
        self.tree_item.command()
    endif
enddef

# Return the depth level of the node in the tree. The level is defined
# recursively: the root has depth 0, and each node has depth equal to the depth
# of its parent increased by 1.
def Node_level(self: dict<any>): number
    if self.parent == {}
        return 0
    endif
    return 1 + self.parent.level(self)
enddef

# Return the string representation of the node. The {level} argument represents
# the depth level of the node in the tree and it is passed for convenience, to
# simplify the implementation and to avoid re-computing the depth.
def Node_render(self: dict<any>, level: number): string
    var indent = repeat(' ', 2 * level)
    var mark = '• '

    if len(self.children) > 0 || self.lazy_open != false
        mark = self.collapsed ? '▸ ' : '▾ '
    endif

    var label = split(self.tree_item.label, "\n")
    extend(self.tree.index, map(range(len(label)), (i, v) => self))

    var repr = indent .. mark .. label[0]
    \          .. join(map(label[1 : ], (_, l) => "\n" .. indent .. '  ' .. l))

    var lines = [repr]
    if !self.collapsed
        if self.lazy_open
            self.lazy_open = false
            self.tree.provider.getChildren((result, children) => Node_get_children_cb(self, result, children), [self.object])
        endif
        for child in self.children
            add(lines, child.render(child, level + 1))
        endfor
    endif

    return join(lines, "\n")
enddef

# Insert a new node in the tree, internally represented by a unique progressive
# integer identifier {id}. The node represents a certain {object} (children of
# {parent}) belonging to a given {tree}, having an associated action to be
# triggered on execution defined by the function object {exec}. If {collapsed}
# is true the node will be rendered as collapsed in the view. If {lazy_open} is
# true, the children of the node will be fetched when the node is expanded by
# the user.
def Node_new(tree: dict<any>, object: number, tree_item: dict<any>, parent: dict<any>): dict<any>
    tree.maxid += 1
    return {
    \ 'id': tree.maxid,
    \ 'tree': tree,
    \ 'object': object,
    \ 'tree_item': tree_item,
    \ 'parent': parent,
    \ 'collapsed': tree_item.collapsibleState ==? 'collapsed',
    \ 'lazy_open': tree_item.collapsibleState !=? 'none',
    \ 'children': [],
    \ 'level': Node_level,
    \ 'exec': Node_exec,
    \ 'set_collapsed': Node_set_collapsed,
    \ 'render': Node_render
    \ }
enddef

# Callback that sets the root node of a given {tree}, creating a new node
# with a {tree_item} representation for the given {object}. If {status} is
# equal to 'success', the root node is set and the tree view is updated
# accordingly, otherwise nothing happens.
def Tree_set_root_cb(tree: dict<any>, object: number, status: string, tree_item: dict<any>): void
    if status ==? 'success'
        tree.maxid = -1
        tree.root = Node_new(tree, object, tree_item, {})
        Tree_render(tree)
    endif
enddef

# Return the node currently under the cursor from the given {tree}.
def Get_node_under_cursor(tree: dict<any>): dict<any>
    var index = min([line('.'), len(tree.index) - 1])
    return tree.index[index]
enddef

# Expand or collapse the node under cursor, and render the tree.
# Please refer to *Node_set_collapsed()* for details about the
# arguments and behaviour.
def Tree_set_collapsed_under_cursor(self: dict<any>, collapsed: number): void
    var node = Get_node_under_cursor(self)
    node.set_collapsed(node, collapsed)
    Tree_render(self)
enddef

# Run the action associated to the node currently under the cursor.
def Tree_exec_node_under_cursor(self: dict<any>): void
    var node = Get_node_under_cursor(self)
    node.exec(node)
enddef

# Render the {tree}. This will replace the content of the buffer with the
# tree view. Clear the index, setting it to a list containing a guard
# value for index 0 (line numbers are one-based).
def Tree_render(tree: dict<any>): void
    if &filetype !=# 'yggdrasil'
        return
    endif

    var cursor = getpos('.')
    tree.index = [-1]
    var text = tree.root.render(tree.root, 0)

    setlocal modifiable
    # WIP
    #silent 1,$delete
    #append(line('$'), [text])
    #normal! G
    #execute "put " text
    #silent 0put=text
    #$d_
    deletebufline(g_tree_top.bufnr, 1, "$")
    map(split(text, "\n"), (i, v) => append(i, [v]))

    setlocal nomodifiable

    setpos('.', cursor)
enddef

# If {status} equals 'success', update all nodes of {tree} representing
# an {obect} with given {tree_item} representation.
def Node_update(tree: dict<any>, object: number, status: string, tree_item: dict<any>): void
    if status !=? 'success'
        return
    endif
    for node in Search_subtree(tree.root, (n) => n.object == object)
        node.tree_item = tree_item
        node.children = []
        node.lazy_open = tree_item.collapsibleState !=? 'none'
    endfor
    Tree_render(tree)
enddef

# Update the view if nodes have changed. If called with no arguments,
# update the whole tree. If called with an {object} as argument, update
# all the subtrees of nodes corresponding to {object}.
def Tree_update(self: dict<any>, args: list<any>): void
    if len(args) == 0 
        self.provider.getChildren((child_status: string, children_list: list<any>) => self.provider.getTreeItem( 
                    \ (tree_status: string, tree_item: dict<any>) => Tree_set_root_cb(self, children_list[0], tree_status, tree_item), children_list[0]),
                    \ [])
    else
        self.provider.getTreeItem((result, item) => Node_update(self, args[0], result, item), args[0])
    endif
enddef

# Destroy the tree view. Wipe out the buffer containing it.
def Tree_wipe(self: dict<any>): void
    execute 'bwipeout ' .. self.bufnr
enddef

# Apply syntax to an Yggdrasil buffer
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

def MutateNode(mode: string): void
    Tree_set_collapsed_under_cursor(g_tree_top, str2nr(mode))
enddef
command -nargs=1 MutateNode MutateNode(<f-args>)
command ExecNode Tree_exec_node_under_cursor(g_tree_top)
command WipeNode Tree_wipe(g_tree_top)

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
    setlocal nospell
    setlocal noswapfile
    setlocal nowrap

    nnoremap <silent> <buffer> <Plug>(yggdrasil-toggle-node) :MutateNode -1<CR>
    nnoremap <silent> <buffer> <Plug>(yggdrasil-open-node) :MutateNode 0<CR>
    nnoremap <silent> <buffer> <Plug>(yggdrasil-close-node) :MutateNode 1<CR>
    nnoremap <silent> <buffer> <Plug>(ggdrasil-execute-node) :ExecNode<CR>
    nnoremap <silent> <buffer> <Plug>(yggdrasil-wipe-tree) :WipeNode<CR>

    if !exists('g:yggdrasil_no_default_maps')
        nmap <silent> <buffer> o    <Plug>(yggdrasil-toggle-node)
        nmap <silent> <buffer> <cr> <Plug>(yggdrasil-execute-node)
        nmap <silent> <buffer> q    <Plug>(yggdrasil-wipe-tree)
    endif
enddef

# Turns the current buffer into an Yggdrasil tree view. Tree data is retrieved
# from the given {provider}, and the state of the tree is stored in a
# buffer-local variable called g_tree_top.
#
# The {bufnr} stores the buffer number of the view, {maxid} is the highest
# known internal identifier of the nodes. The {index} is a list that
# maps line numbers to nodes.
export def New(provider: dict<any>): dict<any>
    g_tree_top = {
    \ 'bufnr': bufnr('%'),
    \ 'maxid': -1,
    \ 'root': {},
    \ 'index': [],
    \ 'provider': provider,
    \ 'set_collapsed_under_cursor': Tree_set_collapsed_under_cursor,
    \ 'exec_node_under_cursor': Tree_exec_node_under_cursor,
    \ 'update': Tree_update,
    \ 'wipe': Tree_wipe,
    \ }

    augroup vim_yggdrasil
        autocmd!
        autocmd FileType yggdrasil Filetype_syntax() | Filetype_settings()
        autocmd BufEnter <buffer> Tree_render(g_tree_top)
    augroup END

    setlocal filetype=yggdrasil

    g_tree_top.update(g_tree_top, [])
    return g_tree_top
enddef
