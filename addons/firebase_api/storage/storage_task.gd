@tool
class_name FirebaseStorageTask
extends RefCounted


enum Task {
	TASK_UPLOAD,
	TASK_UPLOAD_META,
	TASK_DOWNLOAD,
	TASK_DOWNLOAD_META,
	TASK_DOWNLOAD_URL,
	TASK_LIST,
	TASK_LIST_ALL,
	TASK_DELETE,
	TASK_MAX
}

## Emitted when the task is finished. Returns data depending on the success and action of the task.
signal task_finished(data)

var ref # Storage RefCounted (Can't static type due to cyclic reference)

var action : int = -1 : set = set_action

## Data that the tracked task will/has returned.
var data = PackedByteArray() # data can be of any type.

## The percentage of data that has been received.
var progress := 0.0

var result := -1

var finished := false

var response_headers : PackedStringArray

## The returned HTTP response code.
var response_code : int = 0

var _method := -1
var _url : String
var _headers : PackedStringArray


func set_action(value : int) -> void:
	action = value
	match action:
		Task.TASK_UPLOAD:
			_method = HTTPClient.METHOD_POST
		Task.TASK_UPLOAD_META:
			_method = HTTPClient.METHOD_PATCH
		Task.TASK_DELETE:
			_method = HTTPClient.METHOD_DELETE
		_:
			_method = HTTPClient.METHOD_GET
