@tool
class_name StorageReference
extends RefCounted


const DEFAULT_MIME_TYPE := "application/octet-stream"

const MIME_TYPES := {
	"bmp": "image/bmp",
	"css": "text/css",
	"csv": "text/csv",
	"gd": "text/plain",
	"htm": "text/html",
	"html": "text/html",
	"jpeg": "image/jpeg",
	"jpg": "image/jpeg",
	"json": "application/json",
	"mp3": "audio/mpeg",
	"mpeg": "video/mpeg",
	"ogg": "audio/ogg",
	"ogv": "video/ogg",
	"png": "image/png",
	"shader": "text/plain",
	"svg": "image/svg+xml",
	"tif": "image/tiff",
	"tiff": "image/tiff",
	"tres": "text/plain",
	"tscn": "text/plain",
	"txt": "text/plain",
	"wav": "audio/wav",
	"webm": "video/webm",
	"webp": "video/webm",
	"xml": "text/xml",
}

var bucket : String

var full_path : String
var name : String


var parent : StorageReference

var root : StorageReference

var storage # FirebaseStorage (Can't static type due to cyclic reference)

var valid := false


func child(path : String) -> StorageReference:
	if not valid:
		return null
	return storage.ref(full_path + "/" + path)


func put_data(data : PackedByteArray, metadata := {}) -> FirebaseStorageTask:
	if not valid:
		return null
	if not "Content-Length" in metadata and OS.get_name() != "HTML5":
		metadata["Content-Length"] = data.size()
	
	var headers := []
	for key in metadata:
		headers.append(key + ": " + str(metadata[key]))
	
	return storage._upload(data, headers, self, false)


func put_string(data : String, metadata := {}) -> FirebaseStorageTask:
	return put_data(data.to_utf8_buffer(), metadata)


func put_file(file_path : String, metadata := {}) -> FirebaseStorageTask:
	var file = FileAccess.open(file_path, FileAccess.READ)
	var data := file.get_buffer(file.get_length())
	
	if "Content-Type" in metadata:
		metadata["Content-Type"] = MIME_TYPES.get(file_path.get_extension(), DEFAULT_MIME_TYPE)
	
	return put_data(data, metadata)


func get_data() -> FirebaseStorageTask:
	if not valid:
		return null
	storage._download(self, false, false)
	return storage._pending_tasks[-1]


func get_string() -> FirebaseStorageTask:
	var task := get_data()
	task.task_finished.connect(_on_task_finished.bind(task, "stringify"))
	return task


func get_download_url() -> FirebaseStorageTask:
	if not valid:
		return null
	return storage._download(self, false, true)


func get_metadata() -> FirebaseStorageTask:
	if not valid:
		return null
	return storage._download(self, true, false)


func update_metadata(metadata : Dictionary) -> FirebaseStorageTask:
	if not valid:
		return null
	var data := JSON.stringify(metadata).to_utf8_buffer()
	var headers := PackedStringArray(["Accept: application/json"])
	return storage._upload(data, headers, self, true)


func list() -> FirebaseStorageTask:
	if not valid:
		return null
	return storage._list(self, false)


func list_all() -> FirebaseStorageTask:
	if not valid:
		return null
	return storage._list(self, true)


func delete() -> FirebaseStorageTask:
	if not valid:
		return null
	return storage._delete(self)


func _on_task_finished(task : FirebaseStorageTask, action : String) -> void:
	match action:
		"stringify":
			if typeof(task.data) == TYPE_PACKED_BYTE_ARRAY:
				task.data = task.data.get_string_from_utf8()
