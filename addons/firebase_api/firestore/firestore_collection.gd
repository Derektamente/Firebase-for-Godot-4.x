@tool
class_name FirestoreCollection
extends RefCounted


#Connect to this signal to get them independently of the individual FirestoreTask
signal document_added(doc)
signal document_got(doc)
signal document_updated(doc)
signal document_deleted
signal error(code, status, message)

const _AUTHORIZATION_HEADER := "Authorization: Bearer "

const _separator := "/"
const _query_tag := "?"
const _documentId_tag := "documentId="

var collection_name : String
var firestore : FirebaseFirestore

var _base_url : String
var _extended_url : String

var _documents := {}
var _request_queues := {}

# ----------------------- Requests

func get_doc(document_id : String) -> FirestoreTask:
	var task : FirestoreTask = FirestoreTask.new()
	task.action = FirestoreTask.Task.TASK_GET
	task.data = collection_name + "/" + document_id
	var url = _get_request_url() + _separator + document_id.replace(" ", "%20")
	
	task.document_got.connect(_on_document_got)
	task.task_finished.connect(_on_task_finished.bind(document_id),CONNECT_DEFERRED)
	_process_request(task, document_id, url)
	return task


func add(document_id : String, fields : Dictionary = {}) -> FirestoreTask:
	var task : FirestoreTask = FirestoreTask.new()
	task.action = FirestoreTask.Task.TASK_POST
	task.data = collection_name + "/" + document_id
	var url = _get_request_url() + _query_tag + _documentId_tag + document_id
	
	task.document_added.connect(_on_document_added)
	task.task_finished.connect(_on_task_finished.bind(document_id),CONNECT_DEFERRED)
	_process_request(task, document_id, url, JSON.stringify(FirestoreDocument.dict2fields(fields)))
	return task


func update(document_id : String, fields : Dictionary = {}) -> FirestoreTask:
	var task : FirestoreTask = FirestoreTask.new()
	task.action = FirestoreTask.Task.TASK_PATCH
	task.data = collection_name + "/" + document_id
	var url = _get_request_url() + _separator + document_id.replace(" ", "%20") + "?"
	for key in fields.keys():
		url += "updateMask.fieldPaths=" + key + "&"
	url = url.rstrip("&")
	
	task.document_updated.connect(_on_document_updated)
	task.task_finished.connect(_on_task_finished.bind(document_id),CONNECT_DEFERRED)
	_process_request(task, document_id, url, JSON.stringify(FirestoreDocument.dict2fields(fields)))
	return task


func delete(document_id : String) -> FirestoreTask:
	var task : FirestoreTask = FirestoreTask.new()
	task.action = FirestoreTask.Task.TASK_DELETE
	task.data = collection_name + "/" + document_id
	var url = _get_request_url() + _separator + document_id.replace(" ", "%20")
	
	task.document_deleted.connect(_on_document_deleted)
	task.task_finished.connect(_on_task_finished.bind(document_id),CONNECT_DEFERRED)
	_process_request(task, document_id, url)
	return task


# ----------------- Functions
func _get_request_url() -> String:
	return _base_url + _extended_url + collection_name


func _process_request(task : FirestoreTask, document_id : String, url : String, fields := "") -> void:
	if Firebase.Auth.auth.is_empty():
		Firebase._print("Unauthenticated request issued...")
		Firebase.Auth.login_anonymous()
		var result : Array = await Firebase.Auth.auth_request
		if result[0] != 1:
			Firebase.Firestore._check_auth_error(result[0], result[1])
			return
		Firebase._print("Client authenticated as Anonymous User.")
	
	task._url = url
	task._fields = fields
	task._headers = PackedStringArray([_AUTHORIZATION_HEADER + Firebase.Auth.auth.idtoken])
	if _request_queues.has(document_id) and not _request_queues[document_id].is_empty():
		_request_queues[document_id].append(task)
	else:
		_request_queues[document_id] = []
		firestore._pooled_request(task)


func _on_task_finished(task : FirestoreTask, document_id : String) -> void:
	if not _request_queues[document_id].is_empty():
		task._push_request(task._url, _AUTHORIZATION_HEADER + Firebase.Auth.auth.idtoken, task._fields)


func _on_document_got(document : FirestoreDocument):
	document_got.emit(document)


func _on_document_added(document : FirestoreDocument):
	document_added.emit(document)


func _on_document_updated(document : FirestoreDocument):
	document_updated.emit(document)


func _on_document_deleted():
	document_deleted.emit()
