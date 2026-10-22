extends SceneTree
func _init():
    var m = StandardMaterial3D.new()
    print('StandardMaterial3D has orm_texture? ', 'orm_texture' in m)
    var orm = ORMMaterial3D.new()
    print('ORMMaterial3D has orm_texture? ', 'orm_texture' in orm)
    quit(0)
