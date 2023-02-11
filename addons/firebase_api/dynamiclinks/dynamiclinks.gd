@tool
class_name FirebaseDynamicLinks
extends Node


signal dynamic_link_generated(link_result)

const _AUTHORIZATION_HEADER := "Authorization: Bearer "
const _API_VERSION := "v1"

var request := -1

var _base_url : String

var _request_list_node : HTTPRequest

var _headers : PackedStringArray

enum Requests {
	NONE = -1,
	GENERATE
   }


func _setup(config_json : Dictionary) -> void:
	_base_url = "https://firebasedynamiclinks.googleapis.com/v1/shortLinks?key=" + Firebase._config.apiKey
	_request_list_node = HTTPRequest.new()
	_request_list_node.request_completed.connect(_on_request_completed)
	add_child(_request_list_node)


var _link_request_body : Dictionary = {
	"dynamicLinkInfo": {
		"domainUriPrefix": "",
		"link": "",
		"androidInfo": {
			"androidPackageName": ""
		},
		"iosInfo": {
			"iosBundleId": ""
		}
		},
	"suffix": {
		"option": ""
	}
	}

## This function is used to generate a dynamic link using the Firebase REST API
## It will return a JSON with the shortened link
func generate_dynamic_link(long_link : String, APN : String, IBI : String, is_unguessable : bool) -> void:
	request = Requests.GENERATE
	_link_request_body.dynamicLinkInfo.domainUriPrefix = Firebase._config.domainUriPrefix
	_link_request_body.dynamicLinkInfo.link = long_link
	_link_request_body.dynamicLinkInfo.androidInfo.androidPackageName = APN
	_link_request_body.dynamicLinkInfo.iosInfo.iosBundleId = IBI
	if is_unguessable:
		_link_request_body.suffix.option = "UNGUESSABLE"
	else:
		_link_request_body.suffix.option = "SHORT"
	_request_list_node.request(_base_url, _headers, HTTPClient.METHOD_POST, JSON.stringify(_link_request_body))


func _on_request_completed(result : int, response_code : int, headers : PackedStringArray, body : PackedByteArray) -> void:
	var result_body : Dictionary = JSON.parse_string(body.get_string_from_utf8())
	dynamic_link_generated.emit(result_body.shortLink)
	request = Requests.NONE
