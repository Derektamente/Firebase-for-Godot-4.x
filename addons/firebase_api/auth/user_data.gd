@tool
class_name FirebaseUserData
extends RefCounted


var local_id : String
var email : String
var email_verified := false
var password_updated_at : float = 0
var last_login_at : float = 0
var created_at : float = 0
var provider_user_info : Array

var provider_id : String
var display_name : String
var photo_url : String


func _init(p_userdata : Dictionary):
	local_id = p_userdata.get("localId", "")
	email = p_userdata.get("email", "")
	email_verified = p_userdata.get("emailVerified", false)
	last_login_at = float(p_userdata.get("lastLoginAt", 0))
	created_at = float(p_userdata.get("createdAt", 0))
	password_updated_at = float(p_userdata.get("passwordUpdatedAt", 0))
	display_name = p_userdata.get("displayName", "")
	provider_user_info = p_userdata.get("providerUserInfo", [])
	if not provider_user_info.is_empty():
		provider_id = provider_user_info[0].get("providerId", "")
		photo_url = provider_user_info[0].get("photoUrl", "")
		display_name = provider_user_info[0].get("displayName", "")
