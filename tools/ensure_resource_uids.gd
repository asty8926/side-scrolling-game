extends SceneTree
## Add missing `uid://` references to project .tscn / .tres files, using each
## path's existing Godot UID when it has one and a stable id otherwise.
## Does not rewrite property values.
## Usage: godot --headless --path . -s res://tools/ensure_resource_uids.gd

func _init() -> void:
	var paths: PackedStringArray = _collect()
	var changed: int = 0
	var failed: int = 0
	for path: String in paths:
		var result: int = _patch(path)
		if result < 0:
			failed += 1
		elif result > 0:
			changed += 1
	print("ensure_resource_uids: %d file(s) updated, %d unchanged, %d failure(s)" % [changed, paths.size() - changed - failed, failed])
	quit(1 if failed > 0 else 0)


func _collect() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	_walk("res://", out)
	out.sort()
	return out


func _walk(dir_path: String, out: PackedStringArray) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var child: String = dir_path.path_join(name)
		if dir.current_is_dir():
			if name in PackedStringArray(["addons", "android", "build", "reports"]):
				name = dir.get_next()
				continue
			_walk(child, out)
		elif name.ends_with(".tscn") or name.ends_with(".tres"):
			out.append(child)
		name = dir.get_next()
	dir.list_dir_end()


## 1 = patched, 0 = already complete, -1 = failed.
func _patch(path: String) -> int:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("ensure_resource_uids: cannot read %s" % path)
		return -1
	var original: String = file.get_as_text()
	file = null
	var lines: PackedStringArray = original.split("\n")
	if lines.is_empty():
		return 0
	var dirty: bool = false
	var header: String = lines[0]
	if header.begins_with("[gd_scene") or header.begins_with("[gd_resource"):
		if not header.contains("uid=\""):
			lines[0] = header.trim_suffix("]") + " uid=\"%s\"]" % _uid_for(path)
			dirty = true
	for i: int in lines.size():
		var line: String = lines[i]
		if not line.begins_with("[ext_resource") or line.contains("uid=\""):
			continue
		var resource_path: String = _ext_path(line)
		if resource_path.is_empty():
			push_error("ensure_resource_uids: no path in %s: %s" % [path, line])
			return -1
		var uid: String = _uid_for(resource_path)
		var with_id: String = line.replace(" path=\"", " uid=\"%s\" path=\"" % uid)
		if with_id == line:
			push_error("ensure_resource_uids: could not insert uid in %s: %s" % [path, line])
			return -1
		lines[i] = with_id
		dirty = true
	if not dirty:
		return 0
	var text: String = "\n".join(lines)
	file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("ensure_resource_uids: cannot write %s" % path)
		return -1
	file.store_string(text)
	return 1


func _ext_path(line: String) -> String:
	var start: int = line.find("path=\"")
	if start < 0:
		return ""
	start += 6
	var end: int = line.find("\"", start)
	if end < 0:
		return ""
	return line.substr(start, end - start)


func _uid_for(path: String) -> String:
	var existing: String = ResourceUID.path_to_uid(path)
	if existing.begins_with("uid://"):
		return existing
	var id: int = ResourceUID.create_id_for_path(path)
	if not ResourceUID.has_id(id):
		ResourceUID.add_id(id, path)
	return ResourceUID.id_to_text(id)
