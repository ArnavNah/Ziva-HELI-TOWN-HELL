
extends SceneTree
func _init():
    var scr = load('res://src/ui/menus/loading_screen.gd').new()
    root.add_child(scr)
    print('terminal_log_label vertical_alignment:', scr.terminal_log_label.vertical_alignment)
    print('terminal_log_label size:', scr.terminal_log_label.size)
    print('terminal_log_label position:', scr.terminal_log_label.position)
    quit(0)
