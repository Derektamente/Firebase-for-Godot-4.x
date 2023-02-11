@tool
class_name FirebaseRealtime
extends Node

# This will create a reference in your realtime database.
# This means that actions performed through this reference will START from there,
# but you can always specify a more precise path and listen for changes or update the data.
# If you DON'T specify a path (where allowed), actions will be performed at the reference root.
# Calling this method without a path will create a reference of the entire database.
# You can have more references at the same time.
func get_realtime_reference(path := "", filter := {}) -> RealtimeReference:
	var firebase_reference := RealtimeReference.new()
	var pusher := HTTPRequest.new()
	var listener := HTTPSSEClient.new()
	firebase_reference.setup(path, filter, pusher, listener)
	add_child(firebase_reference)
	return firebase_reference
