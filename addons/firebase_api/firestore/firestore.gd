@tool
class_name FirebaseFirestore
extends Node


const _API_VERSION := "v1"

signal documents_listed(documents)
signal result_query(result)
signal task_error(error)

enum Requests {
	NONE = -1,
	LIST,
	QUERY
}

const _AUTHORIZATION_HEADER := "Authorization: Bearer "

const _MAX_POOLED_REQUEST_AGE = 30

var request := -1

var persistence_enabled := true

var collections : Dictionary

## A Dictionary containing all authentication fields for the current logged user.

var _base_url : String
var _extended_url : String
var _query_suffix := ":runQuery"

var _request_list_node : HTTPRequest
var _requests_queue : Array
var _current_query : FirestoreQuery

var _http_request_pool := []


func _process(delta : float) -> void:
	for i in range(_http_request_pool.size() - 1, -1, -1):
		var request = _http_request_pool[i]
		if not request.get_meta("requesting"):
			var lifetime: float = request.get_meta("lifetime") + delta
			if lifetime > _MAX_POOLED_REQUEST_AGE:
				request.queue_free()
				_http_request_pool.remove_at(i)
			request.set_meta("lifetime", lifetime)


func collection(path : String) -> FirestoreCollection:
	if not collections.has(path):
		var coll : FirestoreCollection = FirestoreCollection.new()
		coll._extended_url = _extended_url
		coll._base_url = _base_url
		coll.collection_name = path
		coll.firestore = self
		collections[path] = coll
		return coll
	else:
		return collections[path]


func query(query : FirestoreQuery) -> FirestoreTask:
	var firestore_task : FirestoreTask = FirestoreTask.new()
	firestore_task.result_query.connect(_on_result_query)
	firestore_task.task_error.connect(_on_task_error)
	firestore_task.action = FirestoreTask.Task.TASK_QUERY
	var body : Dictionary = { structuredQuery = query.query }
	var url : String = _base_url + _extended_url + _query_suffix
	
	firestore_task.data = query
	firestore_task._fields = JSON.stringify(body)
	firestore_task._url = url
	_pooled_request(firestore_task)
	return firestore_task


func list(path : String, page_size : int = 0, page_token := "", order_by := "") -> FirestoreTask:
	var firestore_task := FirestoreTask.new()
	firestore_task.documents_listed.connect(_on_documents_listed)
	firestore_task.task_error.connect(_on_task_error)
	firestore_task.action = FirestoreTask.Task.TASK_LIST
	var url : String = _base_url + _extended_url + path
	if page_size != 0:
		url += "?pageSize=" + str(page_size)
	if page_token != "":
		url += "&pageToken=" + page_token
	if order_by != "":
		url += "&orderBy=" + order_by
	
	firestore_task.data = [path, page_size, page_token, order_by]
	firestore_task._url = url
	_pooled_request(firestore_task)
	return firestore_task


func _setup(config_json : Dictionary) -> void:
	_extended_url = "projects/" + Firebase._config.projectId + "/databases/(default)/documents/"
	_base_url = "https://firestore.googleapis.com/" + _API_VERSION + "/"


func _pooled_request(task : FirestoreTask) -> void:
	if Firebase.Auth.auth.is_empty():
		Firebase._print("Unauthenticated request issued...")
		Firebase.Auth.login_anonymous()
		var result : Array = await Firebase.Auth.auth_request
		if result[0] != 1:
			_check_auth_error(result[0], result[1])
		Firebase._print("Client connected as Anonymous")
	
	task._headers = PackedStringArray([_AUTHORIZATION_HEADER + Firebase.Auth.auth.idtoken])
	
	var http_request : HTTPRequest
	for request in _http_request_pool:
		if not request.get_meta("requesting"):
			http_request = request
			break
	
	if not http_request:
		http_request = HTTPRequest.new()
		http_request.timeout = 5
		_http_request_pool.append(http_request)
		add_child(http_request)
		http_request.request_completed.connect(_on_pooled_request_completed.bind(http_request))
	
	http_request.set_meta("requesting", true)
	http_request.set_meta("lifetime", 0.0)
	http_request.set_meta("task", task)
	http_request.request(task._url, task._headers, task._method, task._fields)


# -------------


func _on_documents_listed(_listed_documents : Array):
	documents_listed.emit(_listed_documents)


func _on_result_query(result : Array):
	result_query.emit(result)


func _on_task_error(error):
	task_error.emit(error)
	Firebase._printerr(str(error))


func _on_pooled_request_completed(result : int, response_code : int, headers : PackedStringArray, body : PackedByteArray, request : HTTPRequest) -> void:
	request.get_meta("task")._on_request_completed(result, response_code, headers, body)
	request.set_meta("requesting", false)


func _check_auth_error(code : int, message : String) -> void:
	var err : String
	match code:
		400: err = "Please, enable Anonymous Sign-in method or Authenticate the Client before issuing a request (best option)"
	Firebase._printerr(err)
