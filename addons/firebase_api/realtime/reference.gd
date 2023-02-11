@tool
class_name RealtimeReference
extends Node


signal new_data_update(_update : Dictionary)
signal patch_data_update(_update : Dictionary)
signal delete_data_update(_update : Dictionary)

signal push_successful()
signal push_failed()

var _pusher : HTTPRequest
var _listener : HTTPSSEClient
var _filter_query : Dictionary
var _db_path : String
var _cached_filter : String
var _push_queue : Array
var _update_queue : Array
var _delete_queue : Array
var _can_connect_to_host := false

var _headers : PackedStringArray


func setup(path : String, filter_query_dict : Dictionary, pusher_ref : HTTPRequest, listener_ref : HTTPSSEClient) -> void:
	_db_path = path
	_filter_query = filter_query_dict
	
	_pusher = pusher_ref
	_pusher.request_completed.connect(on_push_request_complete)
	add_child(_pusher)
	
	_listener = listener_ref
	_listener.new_sse_event.connect(on_new_sse_event)
	var base_url = _get_list_url(false).trim_suffix("/")
	var extended_url = "/" + _db_path + _get_remaining_path(false)
	var port = -1
	_listener.set_coordinates(base_url, extended_url, port)
	add_child(_listener)


func _get_list_url(with_port := true) -> String:
	var url = Firebase._config.databaseURL.trim_suffix("/")
	return url + "/"


func _get_remaining_path(is_push := true) -> String:
	var remaining_path : String
	if _filter_query.is_empty() or is_push:
		remaining_path = ".json?auth=" + Firebase.Auth.auth.idtoken
	else:
		remaining_path = ".json?" + _get_filter() + "&auth=" + Firebase.Auth.auth.idtoken

	return remaining_path


func _get_filter():
	if _filter_query.is_empty():
		return ""
	if _cached_filter.is_empty():
		_cached_filter = ""
		if _filter_query.has("orderBy"):
			_cached_filter += "orderBy=" + '"' + _filter_query.orderBy + '"'
			_filter_query.erase("orderBy")
		else:
			_cached_filter += "orderBy=" + '"$key"'
		for key in _filter_query.keys():
			_cached_filter += "&" + key + "=" + str(_filter_query[key])

	return _cached_filter


######## LISTEN
func on_new_sse_event(headers : Dictionary, event : String, data) -> void:
	if event != "keep-alive":
		var _update := {"data" : data, "path" : _db_path}
		if event == "put":
			new_data_update.emit(_update)
		elif event == "patch":
			patch_data_update.emit(_update)
		elif event == "delete":
			delete_data_update.emit(_update)


######## PUSH
# Puts data in your reference's root with an automatically generated ID
func push(data) -> void:
	var to_push = JSON.stringify(data)
	if _pusher.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
		_pusher.request(_get_list_url() + _db_path + _get_remaining_path(), _headers, HTTPClient.METHOD_POST, to_push)
	else:
		_push_queue.append(data)


# Puts/updates data in the given path
func update(data : Dictionary, path : String = "") -> void:
	path = path.strip_edges(true, true)

	if path == "/":
		path = ""

	var to_update = JSON.stringify(data)
	var status = _pusher.get_http_client_status()
	if status == HTTPClient.STATUS_DISCONNECTED || status != HTTPClient.STATUS_REQUESTING:
		var resolved_path = (_get_list_url() + _db_path + "/" + path + _get_remaining_path())

		_pusher.request(resolved_path, _headers, HTTPClient.METHOD_PATCH, to_update)
	else:
		_update_queue.append({"path": path, "data": data})


# Deletes data in the given path
func delete(path : String = "") -> void:
	if _pusher.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
		_pusher.request(_get_list_url() + _db_path + "/" + path + _get_remaining_path(), _headers, HTTPClient.METHOD_DELETE, "")
	else:
		_delete_queue.append(path)


func on_push_request_complete(result : int, response_code : int, headers : PackedStringArray, body : PackedByteArray) -> void:
	if response_code == HTTPClient.RESPONSE_OK:
		push_successful.emit()
	else:
		push_failed.emit()

	if _push_queue.size() > 0:
		push(_push_queue.pop_front())
		return
	if _update_queue.size() > 0:
		var e = _update_queue.pop_front()
		update(e.path, e.data)
		return
	if _delete_queue.size() > 0:
		delete(_delete_queue.pop_front())
