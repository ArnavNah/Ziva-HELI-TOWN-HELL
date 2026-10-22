extends RefCounted
## Tests select a separate directory before any autoload touches the real profile.
static func path_for(filename: String) -> String:
	var directory := OS.get_environment("ZIVA_TEST_DATA_DIR")
	if directory.is_empty():
		return "user://" + filename
	DirAccess.make_dir_recursive_absolute(directory)
	return directory.path_join(filename)

static func write_json(path: String, data: Dictionary) -> Error:
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if not file:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return error
	if FileAccess.file_exists(path):
		error = DirAccess.copy_absolute(path, path + ".bak")
		if error != OK:
			return error
	return DirAccess.rename_absolute(temporary, path)
