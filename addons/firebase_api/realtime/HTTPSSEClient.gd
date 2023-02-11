@tool
class_name  HTTPSSEClient
extends Node


signal new_sse_event(headers, event, data)
signal connected
signal connection_error(error)

var is_connected = false

var httpclient := HTTPClient.new()
var domain
var url_after_domain
var port
var connection_in_progress = false
var is_requested = false


func set_coordinates(_domain : String, _url_after_domain : String, _port := -1) -> void:
	domain = _domain
	url_after_domain = _url_after_domain
	port = _port


func attempt_to_connect() -> void:
	var err = httpclient.connect_to_host(domain, port)
	if err == OK:
		connected.emit()
		is_connected = true
	else:
		connection_error.emit(str(err))


func attempt_to_request(httpclient_status) -> void:
	if httpclient_status == HTTPClient.STATUS_CONNECTING or httpclient_status == HTTPClient.STATUS_RESOLVING:
		return

	if httpclient_status == HTTPClient.STATUS_CONNECTED:
		var err = httpclient.request(HTTPClient.METHOD_POST, url_after_domain, ["Accept: text/event-stream"])
		if err == OK:
			is_requested = true


func _process(delta) -> void:
	if not is_connected:
		if not connection_in_progress:
			attempt_to_connect()
			connection_in_progress = true
		return
	httpclient.poll()
	var httpclient_status = httpclient.get_status()
	if not is_requested:
		attempt_to_request(httpclient_status)
		return

	if httpclient.has_response() or httpclient_status == HTTPClient.STATUS_BODY:
		var headers = httpclient.get_response_headers_as_dictionary()
		if httpclient_status == HTTPClient.STATUS_BODY:
			httpclient.poll()
			var chunk = httpclient.read_response_body_chunk()
			if chunk.size() == 0:
				return
			else:
				var body = chunk.get_string_from_utf8()
				if body != null:
					var event_data : Dictionary

					var event_idx = body.find("event:")
					if event_idx == -1:
						event_data.event = "continue_internal"
					else:
						var data_idx = body.find("data:", event_idx + "event:".length())
						var event = body.substr(event_idx, data_idx)
						event = event.replace("event:", "").strip_edges()
						event_data.event = event

						var data_string = body.substr(data_idx + "data:".length()).strip_edges()
						var data = JSON.parse_string(data_string)
						if data != null:
							while data.path != "/":
								var segment = data.path.substr(data.path.rfind("/") + 1)
								var remaining = data.path.trim_suffix("/" + segment)
								if remaining == "":
									remaining = "/"
								data = {"path" : remaining, "data" : {segment : data.data}}
							event_data.data = data.data
					
					if not event_data.event in ["keep-alive", "continue_internal"]:
						if chunk.size() > 0:
							chunk.resize(0)
							new_sse_event.emit(headers, event_data.event, event_data.data)
					elif event_data.event != "continue_internal":
						chunk.resize(0)
