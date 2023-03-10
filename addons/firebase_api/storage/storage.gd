@tool
class_name FirebaseStorage
extends Node


const _API_VERSION := "v0"

signal task_successful(result, response_code, data)
signal task_failed(result, response_code, data)

## The current storage bucket the Storage API is referencing.
var bucket : String

## Whether a task is currently being processed.
var requesting := false

var _references : Dictionary

var _base_url : String
var _extended_url := "/[API_VERSION]/b/[APP_ID]/o/[FILE_PATH]"
var _root_ref : StorageReference

var _http_client : HTTPClient = HTTPClient.new()
var _pending_tasks : Array

var _current_task : FirebaseStorageTask
var _response_code : int
var _response_headers : PackedStringArray
var _response_data : PackedByteArray
var _content_length : int
var _reading_body : bool


func _notification(what : int) -> void:
	if what == NOTIFICATION_INTERNAL_PROCESS:
		_internal_process(get_process_delta_time())


func _internal_process(_delta : float) -> void:
	if not requesting:
		set_process_internal(false)
		return
	
	var task = _current_task
	
	match _http_client.get_status():
		HTTPClient.STATUS_DISCONNECTED:
			_http_client.connect_to_host(_base_url, 443)
		
		HTTPClient.STATUS_RESOLVING, \
		HTTPClient.STATUS_REQUESTING, \
		HTTPClient.STATUS_CONNECTING:
			_http_client.poll()
		
		HTTPClient.STATUS_CONNECTED:
			var err := _http_client.request_raw(task._method, task._url, task._headers, task.data)
			if err:
				_finish_request(HTTPRequest.RESULT_CONNECTION_ERROR)
		
		HTTPClient.STATUS_BODY:
			if _http_client.has_response() or _reading_body:
				_reading_body = true
				
				# If there is a response...
				if _response_headers.is_empty():
					_response_headers = _http_client.get_response_headers() # Get response headers.
					_response_code = _http_client.get_response_code()
					
					for header in _response_headers:
						if "Content-Length" in header:
							_content_length = header.trim_prefix("Content-Length: ").to_int()
				
				_http_client.poll()
				var chunk = _http_client.read_response_body_chunk() # Get a chunk.
				if chunk.size() == 0:
					# Got nothing, wait for buffers to fill a bit.
					pass
				else:
					_response_data += chunk # Append to read buffer.
					if _content_length != 0:
						task.progress = float(_response_data.size()) / _content_length
				
				if _http_client.get_status() != HTTPClient.STATUS_BODY:
					task.progress = 1.0
					_finish_request(HTTPRequest.RESULT_SUCCESS)
			else:
				task.progress = 1.0
				_finish_request(HTTPRequest.RESULT_SUCCESS)
		
		HTTPClient.STATUS_CANT_CONNECT:
			_finish_request(HTTPRequest.RESULT_CANT_CONNECT)
		HTTPClient.STATUS_CANT_RESOLVE:
			_finish_request(HTTPRequest.RESULT_CANT_RESOLVE)
		HTTPClient.STATUS_CONNECTION_ERROR:
			_finish_request(HTTPRequest.RESULT_CONNECTION_ERROR)
		HTTPClient.STATUS_TLS_HANDSHAKE_ERROR:
			_finish_request(HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR)


## Returns a reference to a file or folder in the storage bucket. It's this reference that should be used to control the file/folder on the server end.
func ref(path := "") -> StorageReference:
	if _base_url == "":
		return null
	
	# Create a root storage reference if there's none
	# and we're not making one.
	if path != "" and not _root_ref:
		_root_ref = ref()
	
	path = _simplify_path(path)
	if not _references.has(path):
		var ref := StorageReference.new()
		_references[path] = ref
		ref.valid = true
		ref.bucket = bucket
		ref.full_path = path
		ref.name = path.get_file()
		ref.parent = ref(path + "/" + "..")
		ref.root = _root_ref
		ref.storage = self
		return ref
	else:
		return _references[path]


func _setup(config_json : Dictionary) -> void:
	_base_url = "https://firebasestorage.googleapis.com"
	if bucket != config_json.storageBucket:
		bucket = config_json.storageBucket
		_http_client.close()


func _upload(data : PackedByteArray, headers : PackedStringArray, ref : StorageReference, meta_only : bool) -> FirebaseStorageTask:
	if _base_url == "" or Firebase.Auth.auth.is_empty():
		return null
	
	var task := FirebaseStorageTask.new()
	task.ref = ref
	task._url = _get_file_url(ref)
	task.action = FirebaseStorageTask.Task.TASK_UPLOAD_META if meta_only else FirebaseStorageTask.Task.TASK_UPLOAD
	task._headers = headers
	task.data = data
	_process_request(task)
	return task


func _download(ref : StorageReference, meta_only : bool, url_only : bool) -> FirebaseStorageTask:
	if _base_url == "" or Firebase.Auth.auth.is_empty():
		return null
	
	var info_task := FirebaseStorageTask.new()
	info_task.ref = ref
	info_task._url = _get_file_url(ref)
	info_task.action = FirebaseStorageTask.Task.TASK_DOWNLOAD_URL if url_only else FirebaseStorageTask.Task.TASK_DOWNLOAD_META
	_process_request(info_task)
	
	if url_only or meta_only:
		return info_task
	
	var task := FirebaseStorageTask.new()
	task.ref = ref
	task._url = _get_file_url(ref) + "?alt=media&token="
	task.action = FirebaseStorageTask.Task.TASK_DOWNLOAD
	_pending_tasks.append(task)
	
	await info_task.task_finished
	if info_task.data and not "error" in info_task.data:
		task._url += info_task.data.downloadTokens
	else:
		task.data = info_task.data
		task.response_headers = info_task.response_headers
		task.response_code = info_task.response_code
		task.result = info_task.result
		task.finished = true
		task.task_finished.emit()
		task_failed.emit(task.result, task.response_code, task.data)
		_pending_tasks.erase(task)
	
	return task


func _list(ref : StorageReference, list_all : bool) -> FirebaseStorageTask:
	if _base_url == "" or Firebase.Auth.auth.is_empty():
		return null
	
	var task := FirebaseStorageTask.new()
	task.ref = ref
	task._url = _get_file_url(_root_ref).trim_suffix("/")
	task.action = FirebaseStorageTask.Task.TASK_LIST_ALL if list_all else FirebaseStorageTask.Task.TASK_LIST
	_process_request(task)
	return task


func _delete(ref : StorageReference) -> FirebaseStorageTask:
	if _base_url == "" or Firebase.Auth.auth.is_empty():
		return null
	
	var task := FirebaseStorageTask.new()
	task.ref = ref
	task._url = _get_file_url(ref)
	task.action = FirebaseStorageTask.Task.TASK_DELETE
	_process_request(task)
	return task


func _process_request(task : FirebaseStorageTask) -> void:
	if requesting:
		_pending_tasks.append(task)
		return
	requesting = true
	
	var headers = Array(task._headers)
	headers.append("Authorization: Bearer " + Firebase.Auth.auth.idtoken)
	task._headers = PackedStringArray(headers)
	
	_current_task = task
	_response_code = 0
	_response_headers = PackedStringArray()
	_response_data = PackedByteArray()
	_content_length = 0
	_reading_body = false
	
	if not _http_client.get_status() in [HTTPClient.STATUS_CONNECTED, HTTPClient.STATUS_DISCONNECTED]:
		_http_client.close()
	set_process_internal(true)


func _finish_request(result : int) -> void:
	var task := _current_task
	requesting = false
	
	task.result = result
	task.response_code = _response_code
	task.response_headers = _response_headers
	
	match task.action:
		FirebaseStorageTask.Task.TASK_DOWNLOAD:
			task.data = _response_data
		
		FirebaseStorageTask.Task.TASK_DELETE:
			_references.erase(task.ref.full_path)
			task.ref.valid = false
			if typeof(task.data) == TYPE_PACKED_BYTE_ARRAY:
				task.data = null
		
		FirebaseStorageTask.Task.TASK_DOWNLOAD_URL:
			var json : Dictionary = JSON.parse_string(_response_data.get_string_from_utf8())
			if not json.is_empty() and json.has("downloadTokens"):
				task.data = _base_url + _get_file_url(task.ref) + "?alt=media&token=" + json.downloadTokens
			else:
				task.data = ""
		
		FirebaseStorageTask.Task.TASK_LIST, FirebaseStorageTask.Task.TASK_LIST_ALL:
			var json : Dictionary = JSON.parse_string(_response_data.get_string_from_utf8())
			var items := []
			if not json.is_empty() and "items" in json:
				for item in json.items:
					var item_name : String = item.name
					if item.bucket != bucket:
						continue
					if not item_name.begins_with(task.ref.full_path):
						continue
					if task.action == FirebaseStorageTask.Task.TASK_LIST:
						var dir_path : Array = item_name.split("/")
						var slash_count : int = task.ref.full_path.count("/")
						item_name = ""
						for i in slash_count + 1:
							item_name += dir_path[i]
							if i != slash_count and slash_count != 0:
								item_name += "/"
						if item_name in items:
							continue
					
					items.append(item_name)
			task.data = items
		
		_:
			task.data = JSON.parse_string(_response_data.get_string_from_utf8())
	
	var next_task : FirebaseStorageTask
	if not _pending_tasks.is_empty():
		next_task = _pending_tasks.pop_front()
	
	task.finished = true
	task.task_finished.emit()
	if typeof(task.data) == TYPE_DICTIONARY and "error" in task.data:
		task_failed.emit(task.result, task.response_code, task.data)
	else:
		task_successful.emit(task.result, task.response_code, task.data)
	
	while true:
		if next_task and not next_task.finished:
			_process_request(next_task)
			break
		elif not _pending_tasks.is_empty():
			next_task = _pending_tasks.pop_front()
		else:
			break


func _get_file_url(ref : StorageReference) -> String:
	var url := _extended_url.replace("[APP_ID]", ref.bucket)
	url = url.replace("[API_VERSION]", _API_VERSION)
	return url.replace("[FILE_PATH]", ref.full_path.replace("/", "%2F"))


# Removes any "../" or "./" in the file path.
func _simplify_path(path : String) -> String:
	var dirs := path.split("/")
	var new_dirs := []
	for dir in dirs:
		if dir == "..":
			new_dirs.pop_back()
		elif dir == ".":
			pass
		else:
			new_dirs.push_back(dir)
	
	var new_path := "/".join(PackedStringArray(new_dirs))
	new_path = new_path.replace("//", "/")
	new_path = new_path.replace("\\", "/")
	return new_path
