
extends SceneTree
func _init():
    var p = load('res://scenes/player/player.tscn').instantiate()
    var v = p.get_node('Visuals')
    var meshes = v.find_children('', 'MeshInstance3D', true, false)
    for m in meshes:
        var trans = m.global_transform
        var aabb = m.get_aabb()
        var bottom_y = (trans * aabb.position).y
        print(m.name, ' min_y: ', bottom_y)
    quit(0)
