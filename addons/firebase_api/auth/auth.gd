@tool
class_name FirebaseAuth
extends HTTPRequest


const _API_VERSION := "v1"

# Emitted for each Auth request issued.
# `result_code` -> Either `1` if auth succeeded or `error_code` if unsuccessful auth request
# `result_content` -> Either `auth_result` if auth succeeded or `error_message` if unsuccessful auth request
signal auth_request(result_code, result_content)

signal signup_succeeded(auth_result)
signal login_succeeded(auth_result)
signal login_failed(code, message)
signal signup_failed(code, message)
signal userdata_received(userdata)
signal token_exchanged(successful)
signal token_refresh_succeeded(auth_result)
signal logged_out()

const RESPONSE_SIGNUP := "identitytoolkit#SignupNewUserResponse"
const RESPONSE_SIGNIN := "identitytoolkit#VerifyPasswordResponse"
const RESPONSE_ASSERTION := "identitytoolkit#VerifyAssertionResponse"
const RESPONSE_USERDATA := "identitytoolkit#GetAccountInfoResponse"
const RESPONSE_CUSTOM_TOKEN := "identitytoolkit#VerifyCustomTokenResponse"

var _base_url : String
var _refresh_request_base_url
var _signup_request_url : String
var _signin_with_oauth_request_url : String
var _signin_request_url : String
var _signin_custom_token_url : String
var _userdata_request_url : String
var _oobcode_request_url : String
var _delete_account_request_url : String
var _update_account_request_url : String

var _refresh_request_url : String
var _google_auth_request_url := "https://accounts.google.com/o/oauth2/v2/auth?"
var _google_token_request_url := "https://oauth2.googleapis.com/token?"

var auth := {}
var _needs_refresh := false
var is_busy := false

var tcp_server : TCPServer = TCPServer.new()
var tcp_timer : Timer = Timer.new()
var tcp_timeout : float = 0.5

var _headers := [
	"Accept: application/json",
	"Content-Type: application/json"
]

var requesting := -1

enum Requests {
	NONE = -1,
	EXCHANGE_TOKEN,
	LOGIN_WITH_OAUTH
}

var auth_request_type := -1

enum Auth_Type {
	NONE = -1,
	LOGIN_EP,
	LOGIN_ANON,
	LOGIN_CT,
	LOGIN_OAUTH,
	SIGNUP_EP
}

var _login_request_body := {
	"email":"",
	"password":"",
	"returnSecureToken": true,
}

var _post_body := "id_token=[GOOGLE_ID_TOKEN]&providerId=[PROVIDER_ID]"
var _request_uri := "[REQUEST_URI]"

var _oauth_login_request_body := {
	"postBody":"",
	"requestUri":"",
	"returnIdpCredential":true,
	"returnSecureToken":true
}

var _anonymous_login_request_body := {
	"returnSecureToken":true
}

var _refresh_request_body := {
	"grant_type":"refresh_token",
	"refresh_token":"",
}

var _custom_token_body := {
	"token":"",
	"returnSecureToken":true
}

var _password_reset_body := {
	"requestType":"password_reset",
	"email":"",
}

var _change_email_body := {
	"idToken":"",
	"email":"",
	"returnSecureToken": true,
}

var _change_password_body := {
	"idToken":"",
	"password":"",
	"returnSecureToken": true,
}

var _account_verification_body := {
	"requestType":"verify_email",
	"idToken":"",
}

var _update_profile_body := {
	"idToken":"",
	"displayName":"",
	"photoUrl":"",
	"deleteAttribute":"",
	"returnSecureToken":true
}

var _google_auth_body := {
	"scope":"email openid profile",
	"response_type":"code",
	"redirect_uri":"",
	"client_id":"[CLIENT_ID]"
}

var _google_token_body := {
	"code":"",
	"client_id":"",
	"client_secret":"",
	"redirect_uri":"",
	"grant_type":"authorization_code"
}


func _ready() -> void:
	tcp_timer.wait_time = tcp_timeout
	tcp_timer.timeout.connect(_tcp_stream_timer)
	connect("request_completed",_on_FirebaseAuth_request_completed)


func _setup(config_json : Dictionary) -> void:
	_signup_request_url = "accounts:signUp?key=" + config_json.apiKey
	_signin_request_url = "accounts:signInWithPassword?key=" + config_json.apiKey
	_signin_custom_token_url = "accounts:signInWithCustomToken?key=" + config_json.apiKey
	_signin_with_oauth_request_url = "accounts:signInWithIdp?key=" + config_json.apiKey
	_userdata_request_url = "accounts:lookup?key=" + config_json.apiKey
	_refresh_request_url = "/v1/token?key=" + config_json.apiKey
	_oobcode_request_url = "accounts:sendOobCode?key=" + config_json.apiKey
	_delete_account_request_url = "accounts:delete?key=" + config_json.apiKey
	_update_account_request_url = "accounts:update?key=" + config_json.apiKey
	_base_url = "https://identitytoolkit.googleapis.com/" + _API_VERSION + "/"
	_refresh_request_base_url = "https://securetoken.googleapis.com"


func _is_ready() -> bool:
	if is_busy:
		Firebase._printerr("Firebase Auth is currently busy and cannot process this request")
		return false
	else:
		if _base_url == "":
			Firebase._printerr("Firebase hasn't been configured")
			return false
		return true


# Synchronous call to check if any user is already logged in.
func is_logged_in() -> bool:
	return auth != null and auth.has("idtoken")


# Called with Firebase.Auth.signup_with_email_and_password(email, password)
# You must pass in the email and password to this function for it to work correctly
func signup_with_email_and_password(email : String, password : String) -> void:
	if _is_ready():
		is_busy = true
		_login_request_body.email = email
		_login_request_body.password = password
		auth_request_type = Auth_Type.SIGNUP_EP
		request(_base_url + _signup_request_url, _headers, HTTPClient.METHOD_POST, JSON.stringify(_login_request_body))


# Called with Firebase.Auth.anonymous_login()
# A successful request is indicated by a 200 OK HTTP status code. 
# The response contains the Firebase ID token and refresh token associated with the anonymous user.
# The 'mail' field will be empty since no email is linked to an anonymous user
func login_anonymous() -> void:
	if _is_ready():
		is_busy = true
		auth_request_type = Auth_Type.LOGIN_ANON
		request(_base_url + _signup_request_url, _headers, HTTPClient.METHOD_POST, JSON.stringify(_anonymous_login_request_body))


func login_with_email_and_password(email : String, password : String) -> void:
	if _is_ready():
		is_busy = true
		_login_request_body.email = email
		_login_request_body.password = password
		auth_request_type = Auth_Type.LOGIN_EP
		request(_base_url + _signin_request_url, _headers, HTTPClient.METHOD_POST, JSON.stringify(_login_request_body))


# The token needs to be generated using an external service/function
func login_with_custom_token(token : String) -> void:
	if _is_ready():
		is_busy = true
		_custom_token_body.token = token
		auth_request_type = Auth_Type.LOGIN_CT
		request(_base_url + _signin_custom_token_url, _headers, HTTPClient.METHOD_POST, JSON.stringify(_custom_token_body))

# Open a web page in browser redirecting to Google oAuth2 page for the current project
# Once given user's authorization, a token will be generated.
# NOTE** with this method, the authorization process will be copy-pasted

func get_google_auth(redirect_uri : String = "urn:ietf:wg:oauth:2.0:oob", client_id : String = Firebase._config.clientId) -> void:
	var url_endpoint : String = _google_auth_request_url
	_google_auth_body.redirect_uri = redirect_uri


func get_google_auth_manual() -> void:
	var url_endpoint : String = _google_auth_request_url
	_google_auth_body.redirect_uri = "urn:ietf:wg:oauth:2.0:oob"
	for key in _google_auth_body.keys():
		url_endpoint += key + "=" + _google_auth_body[key] + "&"
	url_endpoint = url_endpoint.replace("[CLIENT_ID]&", Firebase._config.clientId)
	OS.shell_open(url_endpoint)

# Exchange the authorization oAuth2 code obtained from browser with a proper access id_token
func exchange_google_token(google_token : String, redirect_uri : String = "urn:ietf:wg:oauth:2.0:oob") -> void:
	if _is_ready():
		is_busy = true
		_google_token_body.code = google_token
		_google_token_body.client_id = Firebase._config.clientId
		_google_token_body.client_secret = Firebase._config.clientSecret
		_google_token_body.redirect_uri = redirect_uri
		requesting = Requests.EXCHANGE_TOKEN
		request(_google_token_request_url, _headers, HTTPClient.METHOD_POST, JSON.stringify(_google_token_body))


func get_google_auth_redirect(redirect_uri : String, listen_to_port : int) -> void:
	var url_endpoint : String = _google_auth_request_url
	_google_auth_body.redirect_uri = redirect_uri
	for key in _google_auth_body.keys():
		url_endpoint += key + "=" + _google_auth_body[key] + "&"
	url_endpoint = url_endpoint.replace("[CLIENT_ID]&", Firebase._config.clientId)
	OS.shell_open(url_endpoint)
	await get_tree().create_timer(1).timeout
	add_child(tcp_timer)
	tcp_timer.start()
	tcp_server.listen(listen_to_port, "::")


# Open a web page in browser redirecting to Google oAuth2 page for the current project
# Once given user's authorization, a token will be generated.
# NOTE** the generated token will be automatically captured and a login request will be made if the token is correct
func get_google_auth_localhost(port : int = 49152):
	get_google_auth_redirect("http://localhost:%s/" % port, port)


func _tcp_stream_timer() -> void:
	var peer : StreamPeer = tcp_server.take_connection()
	if peer != null:
		var raw_result : String = peer.get_utf8_string(100)
		if raw_result != "" and raw_result.begins_with("GET"):
			var token : String = raw_result.rsplit("=")[1].rstrip("&scope")
			tcp_server.stop()
			peer.disconnect_from_host()
			tcp_timer.stop()
			remove_child(tcp_timer)
			login_with_oauth(token, _google_auth_body.redirect_uri)


# A token is automatically obtained using an authorization code using @get_google_auth()
func login_with_oauth(_google_token: String, request_uri : String = "urn:ietf:wg:oauth:2.0:oob", provider_id : String = "google.com") -> void:
	var google_token : String = _google_token.uri_decode()
	_exchange_google_token(google_token, request_uri)
	var is_successful : bool = await token_exchanged
	if is_successful and _is_ready():
		is_busy = true
		_oauth_login_request_body.postBody = _post_body.replace("[GOOGLE_ID_TOKEN]", auth.idtoken).replace("[PROVIDER_ID]", provider_id)
		_oauth_login_request_body.requestUri = _request_uri.replace("[REQUEST_URI]", request_uri if request_uri != "urn:ietf:wg:oauth:2.0:oob" else "http://localhost")
		requesting = Requests.LOGIN_WITH_OAUTH
		auth_request_type = Auth_Type.LOGIN_OAUTH
		request(_base_url + _signin_with_oauth_request_url, _headers, HTTPClient.METHOD_POST, JSON.stringify(_oauth_login_request_body))


func _exchange_google_token(google_token : String, redirect_uri : String = "urn:ietf:wg:oauth:2.0:oob") -> void:
	if _is_ready():
		is_busy = true
		_google_token_body.code = google_token
		_google_token_body.redirect_uri = redirect_uri
		_google_token_body.client_id = Firebase._config.clientId
		_google_token_body.client_secret = Firebase._config.clientSecret
		requesting = Requests.EXCHANGE_TOKEN
		request(_google_token_request_url, _headers, HTTPClient.METHOD_POST, JSON.stringify(_google_token_body))


func manual_token_refresh(auth_data):
	auth = auth_data
	var refresh_token = null
	auth = get_clean_keys(auth)
	if auth.has("refreshtoken"):
		refresh_token = auth.refreshtoken
	elif auth.has("refresh_token"):
		refresh_token = auth.refresh_token
	_needs_refresh = true
	_refresh_request_body.refresh_token = refresh_token
	request(_refresh_request_base_url + _refresh_request_url, _headers, HTTPClient.METHOD_POST, JSON.stringify(_refresh_request_body))


# This function is called whenever there is an authentication request to Firebase
# On an error, this function with emit the signal 'login_failed' and print the error to the console
func _on_FirebaseAuth_request_completed(result : int, response_code : int, headers : PackedStringArray, body : PackedByteArray) -> void:
	is_busy = false
	var res
	if response_code == 0:
		# Mocked error results to trigger the correct signal.
		# Can occur if there is no internet connection, or the service is down,
		# in which case there is no json_body (and thus parsing would fail).
		res = {"error": {
			"code": "Connection error",
			"message": "Error connecting to auth service"}}
	else:
		var bod = body.get_string_from_utf8()
		var json_result = JSON.parse_string(bod)
		if json_result == null:
			Firebase._printerr("Error while parsing auth body json")
			auth_request.emit(ERR_PARSE_ERROR, "Error while parsing auth body json")
			return
		res = json_result

	if response_code == HTTPClient.RESPONSE_OK:
		if not res.has("kind"):
			auth = get_clean_keys(res)
			match requesting:
				Requests.EXCHANGE_TOKEN:
					token_exchanged.emit(true)
			begin_refresh_countdown()
			# Refresh token countdown
			auth_request.emit(1, auth)
		else:
			match res.kind:
				RESPONSE_SIGNUP:
					auth = get_clean_keys(res)
					signup_succeeded.emit(auth)
					begin_refresh_countdown()
				RESPONSE_SIGNIN, RESPONSE_ASSERTION, RESPONSE_CUSTOM_TOKEN:
					auth = get_clean_keys(res)
					login_succeeded.emit(auth)
					begin_refresh_countdown()
				RESPONSE_USERDATA:
					var userdata = FirebaseUserData.new(res.users[0])
					userdata_received.emit(userdata)
			auth_request.emit(1, auth)
	else:
		# error message would be INVALID_EMAIL, EMAIL_NOT_FOUND, INVALID_PASSWORD, USER_DISABLED or WEAK_PASSWORD
		if requesting == Requests.EXCHANGE_TOKEN:
			token_exchanged.emit(false)
			login_failed.emit(res.error, res.error_description)
			auth_request.emit(res.error, res.error_description)
		else:
			if auth_request_type == Auth_Type.SIGNUP_EP:
				signup_failed.emit(res.error.code, res.error.message)
			else:
				login_failed.emit(res.error.code, res.error.message)
			auth_request.emit(res.error.code, res.error.message)
	requesting = Requests.NONE
	auth_request_type = Auth_Type.NONE



# Function used to change the email account for the currently logged in user
func change_user_email(email : String) -> void:
	if _is_ready():
		is_busy = true
		_change_email_body.email = email
		_change_email_body.idToken = auth.idtoken
		request(_base_url + _update_account_request_url, _headers, HTTPClient.METHOD_POST, JSON.stringify(_change_email_body))


# Function used to change the password for the currently logged in user
func change_user_password(password : String) -> void:
	if _is_ready():
		is_busy = true
		_change_password_body.password = password
		_change_password_body.idToken = auth.idtoken
		request(_base_url + _update_account_request_url, _headers, HTTPClient.METHOD_POST, JSON.stringify(_change_password_body))


# User Profile handlers 
func update_account(idToken : String, displayName : String, photoUrl : String, deleteAttribute : PackedStringArray, returnSecureToken : bool) -> void:
	if _is_ready():
		is_busy = true
		_update_profile_body.idToken = idToken
		_update_profile_body.displayName = displayName
		_update_profile_body.photoUrl = photoUrl
		_update_profile_body.deleteAttribute = deleteAttribute
		_update_profile_body.returnSecureToken = returnSecureToken
		request(_base_url + _update_account_request_url, _headers, HTTPClient.METHOD_POST, JSON.stringify(_update_profile_body))


# Function to send a account verification email
func send_account_verification_email() -> void:
	if _is_ready():
		is_busy = true
		_account_verification_body.idToken = auth.idtoken
		request(_base_url + _oobcode_request_url, _headers, HTTPClient.METHOD_POST, JSON.stringify(_account_verification_body))


# Function used to reset the password for a user who has forgotten in.
# This will send the users account an email with a password reset link
func send_password_reset_email(email : String) -> void:
	if _is_ready():
		is_busy = true
		_password_reset_body.email = email
		request(_base_url + _oobcode_request_url, _headers, HTTPClient.METHOD_POST, JSON.stringify(_password_reset_body))


# Function called to get all
func get_user_data() -> void:
	if _is_ready():
		is_busy = true
		if not is_logged_in():
			print_debug("Not logged in")
			is_busy = false
			return
						
		request(_base_url + _userdata_request_url, _headers, HTTPClient.METHOD_POST, JSON.stringify({"idToken":auth.idtoken}))


# Function used to delete the account of the currently authenticated user
func delete_user_account() -> void:
	if _is_ready():
		is_busy = true
		request(_base_url + _delete_account_request_url, _headers, HTTPClient.METHOD_POST, JSON.stringify({"idToken":auth.idtoken}))


# Function is called when a new token is issued to a user. The function will yield until the token has expired, and then request a new one.
func begin_refresh_countdown() -> void:
	var refresh_token = null
	var expires_in = 1000
	auth = get_clean_keys(auth)
	if auth.has("refreshtoken"):
		refresh_token = auth.refreshtoken
		expires_in = auth.expiresin
	elif auth.has("refresh_token"):
		refresh_token = auth.refresh_token
		expires_in = auth.expires_in
	if auth.has("userid"):
		auth.localid = auth.userid
	_needs_refresh = true
	token_refresh_succeeded.emit(auth)
	await get_tree().create_timer(float(expires_in)).timeout
	_refresh_request_body.refresh_token = refresh_token
	request(_refresh_request_base_url + _refresh_request_url, _headers, HTTPClient.METHOD_POST, JSON.stringify(_refresh_request_body))


# This function is used to make all keys lowercase
# This is only used to cut down on processing errors from Firebase
func get_clean_keys(auth_result : Dictionary) -> Dictionary:
	var cleaned : Dictionary
	for key in auth_result.keys():
		cleaned[key.replace("_", "").to_lower()] = auth_result[key]
	return cleaned
