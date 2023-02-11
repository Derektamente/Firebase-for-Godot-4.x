@tool
class_name FirebaseFunctions
extends Node


signal task_error(error)

const _AUTHORIZATION_HEADER := "Authorization: Bearer "

const _MAX_POOLED_REQUEST_AGE = 30

var request := -1

var _base_url :=  ""

var _http_request_pool : Array
	
	
func _process(delta : float) -> void:
	for i in range(_http_request_pool.size() - 1, -1, -1):
		var request = _http_request_pool[i]
		if not request.get_meta("requesting"):
			var lifetime: float = request.get_meta("lifetime") + delta
			if lifetime > _MAX_POOLED_REQUEST_AGE:
				request.queue_free()
				_http_request_pool.remove_at(i)
			request.set_meta("lifetime", lifetime)


func execute(function : String, method : int, params : Dictionary = {}, body : Dictionary = {}) -> FunctionTask:
	var function_task : FunctionTask = FunctionTask.new()
	function_task.task_error.connect(_on_task_error)
	
	function_task._method = method
	
	var url : String = _base_url + ("/" if not _base_url.ends_with("/") else "") + function
	function_task._url = url
	
	if not params.is_empty():
		url += "?"
		for key in params.keys():
			url += key + "=" + params[key] + "&"
	
	if not body.is_empty(): 
		function_task._headers = PackedStringArray(["Content-Type: application/json"])
		function_task._fields = JSON.stringify(body)
	
	_pooled_request(function_task)
	return function_task


func _setup(config_json : Dictionary) -> void:
	_base_url = "https://" + config_json.functionsGeoZone + "-" + config_json.projectId + ".cloudfunctions.net/"


func _pooled_request(task : FunctionTask) -> void:
	if Firebase.Auth.auth.is_empty():
		Firebase._print("Unauthenticated request issued...")
		Firebase.Auth.login_anonymous()
		var result : Array = await Firebase.Auth.auth_request
		if result[0] != 1:
			_check_auth_error(result[0], result[1])
		Firebase._print("Client connected as Anonymous")
		
	
	task._headers = Array(task._headers) + [_AUTHORIZATION_HEADER + Firebase.Auth.auth.idtoken]
	
	var http_request : HTTPRequest
	for request in _http_request_pool:
		if not request.get_meta("requesting"):
			http_request = request
			break
	
	if not http_request:
		http_request = HTTPRequest.new()
		_http_request_pool.append(http_request)
		add_child(http_request)
		http_request.request_completed.connect(_on_pooled_request_completed.bind(http_request))
	
	http_request.set_meta("requesting", true)
	http_request.set_meta("lifetime", 0.0)
	http_request.set_meta("task", task)
	http_request.request(task._url, task._headers, task._method, task._fields)


# -------------
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
