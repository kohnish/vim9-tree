vim9script

import "tree.vim"

var g_handle = {}

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

# Define the tree data provider.
#
# The data provider exposes three methods that, given an object as input,
# produce the list of children, the parent object, and the tree item
# representation for the object respectively.
#
# Each method takes as first argument a callback, that is called by the provider
# to return the result asynchronously. The callback takes two arguments, the
# first is a status parameter, the second is the result of the call.
#var g_provider = {
#\ 'getChildren': GetChildren,
#\ 'getParent': GetParent,
#\ 'getTreeItem': GetTreeItem,
#\ }



# Create a tree view with the given provider
#
# This function turns the current buffer into a tree view using data from the
# given provider. Any pre-existing content of the buffer will be devared
# without warning. It is recommended to this function within a newly
# created buffer (usually in a new split window, floating window, or tab).
# Create a new buffer and a new window for the tree view
#topleft vnew
#var g_handle = tree.New(g_provider)

def Main(): void
    var provider = {
    \ 'getChildren': GetChildren,
    \ 'getParent': GetParent,
    \ 'getTreeItem': GetTreeItem,
    \ }

    topleft vnew
    g_handle = tree.New(provider)
enddef

#Main()
