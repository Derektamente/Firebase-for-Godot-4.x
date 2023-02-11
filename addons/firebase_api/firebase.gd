@tool
extends Node


@onready var Auth : FirebaseAuth = $Auth
@onready var Firestore : FirebaseFirestore = $Firestore
@onready var Realtime : FirebaseRealtime = $Realtime
@onready var Storage : FirebaseStorage = $Storage
@onready var Functions : FirebaseFunctions = $Functions
@onready var DynamicLinks : FirebaseDynamicLinks = $DynamicLinks

var _config := {
	"apiKey" : "",
	"authDomain" : "",
	"databaseURL" : "",
	"projectId" : "",
	"storageBucket" : "",
	"messagingSenderId" : "",
	"appId" : "",
	"measurementId" : "",
	"clientId" : "",
	"clientSecret" : "",
	"domainUriPrefix" : "",
	"functionsGeoZone" : "",
}


# Call this method in your main scene's _ready() passing your Firebase config
func setup_modules(config : Dictionary) -> void:
	for key in config:
		_config[key] = config[key]
	for module in get_children():
		if module.has_method("_setup"):
			module._setup(_config)
	

static func _printerr(error : String) -> void:
	printerr("[Firebase Error] >> " + error)


static func _print(msg : String) -> void:
	print("[Firebase] >> " + msg)
