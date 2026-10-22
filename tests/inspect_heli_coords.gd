
extends SceneTree
func _init():
    var p = load('res://scenes/player/player.tscn').instantiate()
    var v = p.get_node('Visuals')
    print('Visuals children:')
    for c in v.get_children():
        print(' - ', c.name, ' (', c.get_class(), ') pos:', c.position)
    var m = v.get_node('ApacheModel')
    print('ApacheModel transform:', m.transform)
    # Check meshes inside ApacheModel
    var meshes = m.find_children('', 'MeshInstance3D', true, false)
    for mesh in meshes:
        var aabb = mesh.get_aabb()
        print('Mesh: ', mesh.name, ' aabb: ', aabb)
    quit(0)
