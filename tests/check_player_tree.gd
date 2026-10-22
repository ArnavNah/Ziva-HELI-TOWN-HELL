extends SceneTree
func _init():
    var p = load('res://scenes/player/player.tscn').instantiate()
    print('Player nodes:')
    _print_tree(p, '')
    quit(0)

func _print_tree(node, indent):
    print(indent + node.name + ' (' + node.get_class() + ')')
    for c in node.get_children():
        _print_tree(c, indent + '  ')
