@tool
class_name FirestoreTask
extends RefCounted


#Connect to this signal to get them only from the individual FirestoreTask
signal task_finished(task)
signal document_added(doc)
signal document_got(doc)
signal document_updated(doc)
signal document_deleted
signal documents_listed(documents)
signal result_query(result)
signal task_error(error)

enum Task {
	TASK_GET,
	TASK_POST,
	TASK_PATCH,
	TASK_DELETE,
	TASK_QUERY,
	TASK_LIST
}

var action := -1 : set = set_action

var data
var error
var document : FirestoreDocument

var _response_headers : PackedStringArray = PackedStringArray()
var _response_code := 0

var _method := -1
var _url : String
var _fields : String
var _headers : PackedStringArray



func _on_request_completed(result : int, response_code : int, headers : PackedStringArray, body : PackedByteArray) -> void:
	var bod
	if JSON.parse_string(body.get_string_from_utf8()) != null:
		bod = JSON.parse_string(body.get_string_from_utf8())

	var failed : bool = bod == null and response_code != HTTPClient.RESPONSE_OK

	if response_code == HTTPClient.RESPONSE_OK:
		data = bod
		match action:
			Task.TASK_POST:
				document = FirestoreDocument.new(bod)
				document_added.emit(document)
			Task.TASK_GET:
				document = FirestoreDocument.new(bod)
				document_got.emit(document)
			Task.TASK_PATCH:
				document = FirestoreDocument.new(bod)
				document_updated.emit(document)
			Task.TASK_DELETE:
				document_deleted.emit()
			Task.TASK_QUERY:
				data = []
				for doc in bod:
					if doc.has('document'):
						data.append(FirestoreDocument.new(doc.document))
				result_query.emit(data)
			Task.TASK_LIST:
				data = []
				if bod.has('documents'):
					for doc in bod.documents:
						data.append(FirestoreDocument.new(doc))
					if bod.has("nextPageToken"):
						data.append(bod.nextPageToken)
				documents_listed.emit(data)
	else:
		error = bod
		task_error.emit(bod)

	task_finished.emit(self)


func set_action(value : int) -> void:
	action = value
	match action:
		Task.TASK_GET, Task.TASK_LIST:
			_method = HTTPClient.METHOD_GET
		Task.TASK_POST, Task.TASK_QUERY:
			_method = HTTPClient.METHOD_POST
		Task.TASK_PATCH:
			_method = HTTPClient.METHOD_PATCH
		Task.TASK_DELETE:
			_method = HTTPClient.METHOD_DELETE


func _merge_dict(dic_a : Dictionary, dic_b : Dictionary, nullify := false) -> Dictionary:
	var ret := dic_a.duplicate(true)
	for key in dic_b:
		var val = dic_b[key]

		if val == null and nullify:
			ret.erase(key)
		elif val is Array:
			ret[key] = _merge_array(ret.get(key) if ret.get(key) else [], val)
		elif val is Dictionary:
			ret[key] = _merge_dict(ret.get(key) if ret.get(key) else {}, val)
		else:
			ret[key] = val
	return ret


func _merge_array(arr_a : Array, arr_b : Array, nullify := false) -> Array:
	var ret := arr_a.duplicate(true)
	ret.resize(len(arr_b))

	var deletions := 0
	for i in len(arr_b):
		var index : int = i - deletions
		var val = arr_b[index]
		if val == null and nullify:
			ret.remove_at(index)
			deletions += i
		elif val is Array:
			ret[index] = _merge_array(ret[index] if ret[index] else [], val)
		elif val is Dictionary:
			ret[index] = _merge_dict(ret[index] if ret[index] else {}, val)
		else:
			ret[index] = val
	return ret
