extends SceneTree
func _init():
    var am = load('res://autoload/audio_manager.gd').new()
    root.add_child(am)
    var stream = am.get_helicopter_rotor_stream()
    print('Stream is null? ', stream == null)
    if stream:
        print('Format: ', stream.format)
        print('Mix rate: ', stream.mix_rate)
        print('Data size: ', stream.data.size())
        print('Loop mode: ', stream.loop_mode)
        print('Loop begin: ', stream.loop_begin, ' end: ', stream.loop_end)
        var max_val = 0
        for i in range(min(1000, stream.data.size() / 2)):
            var val = stream.data.decode_s16(i * 2)
            if abs(val) > max_val: max_val = abs(val)
        print('Max sample in first 1000: ', max_val)
    quit(0)
