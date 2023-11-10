extends Node

@onready var _tree : SceneTree = get_tree() if not Engine.is_editor_hint() else Engine.get_main_loop()

signal resource_loaded(file_path: String)
signal resource_progress(amount: String, progress: String, speed: String)

const _progress_after_msecs := 100
const _progress_after_bytes := 1024 * 1024 * 1
var _thread : Thread
var _error_message : String
var _status := "pending"

func _ready() -> void:
	self.set_process(false)
	self.set_process_input(false)

func import(url: String):
	if _thread == null: _thread = Thread.new()

	var state = _thread.start(Callable(self, "_thread_load").bind(url))
	if state != OK: push_error("Error while starting thread: " + str(state))

func _thread_load(url: String):
	var _request := HTTPRequest.new()
	_request.download_chunk_size = 1024 * 1024 * 1 # 1MB
	_request.use_threads = true
	add_child.call_deferred(_request)
	while not _request.is_node_ready(): await _tree.process_frame

	var regex = RegEx.new()
	regex.compile("^(?>(?<protocol>[a-zA-Z]+)://)?(?<domain>[a-zA-Z0-9.\\-_]*)?(?>:(?<port>\\d{1,5}))?(?<path>[a-zA-Z0-9_\\-/%]+)?/(?<file>[a-zA-Z0-9_\\-.%]+)")
	var url_reg = regex.search(url)
	var file_dir = "user://temp/{dir}".format({ "dir": get_node("/root/Random").alphanumeric(10) })
	var file_name = ""
	var file_ext = ""
	if url_reg:
		file_name = url_reg.get_string("file").get_slice(".", 0)
		file_ext = url_reg.get_string("file").get_slice(".", 1)
	var file_path = "{dir}/{name}.{ext}".format({ "dir": file_dir, "name": file_name, "ext": file_ext })

	if DirAccess.dir_exists_absolute(file_dir): DirAccess.remove_absolute(file_path)
	DirAccess.make_dir_recursive_absolute(file_dir)

	_request.download_file = file_path
	_request.request_completed.connect(Callable(self, "_request_complete"))

	Callable(func():
		var downloaded_bytes = 0
		var body_size = 0
		
		var last_progress_time = Time.get_ticks_msec()
		var last_progress_bytes = 0
		var prev_progress = ""

		while true:
			match _request.get_http_client_status():
				HTTPClient.STATUS_CONNECTING, HTTPClient.STATUS_RESOLVING: await _tree.process_frame
				#HTTPClient.STATUS_CONNECTION_ERROR:
						#_error_message = "Download failed due to connection (read/write) error."
						#break
				#HTTPClient.STATUS_DISCONNECTED:
						#_error_message = "Download failed due to connection lost."
						#break
				HTTPClient.STATUS_CONNECTED, HTTPClient.STATUS_REQUESTING, HTTPClient.STATUS_BODY, _:
					if _error_message: break
					downloaded_bytes = _request.get_downloaded_bytes()
					body_size = _request.get_body_size()
					if downloaded_bytes < 1: await _tree.process_frame
					
					var delta_time = Time.get_ticks_msec() - last_progress_time
					var delta_bytes = downloaded_bytes - last_progress_bytes

					if (delta_time >= _progress_after_msecs) or (delta_bytes >= _progress_after_bytes):
						var _str = _get_progress_string(downloaded_bytes, body_size, delta_time, delta_bytes)
						if _str[1] != prev_progress:
							prev_progress = _str[1]
							call_deferred("emit_signal", "resource_progress", _str[0], _str[1], _str[2])
							last_progress_time = Time.get_ticks_msec()
							last_progress_bytes = downloaded_bytes
							if "100" in _str[1]:
								await _tree.create_timer(1.0).timeout
								break
				#_: print(["get_http_client_status()", _request.get_http_client_status()])
			await _tree.process_frame

		_status = "complete" if not _error_message else "incomplete"
		if _error_message: 
			DirAccess.remove_absolute(file_path)
			push_error(_error_message)

		_request.queue_free()
		_thread_done.call_deferred(_status, file_path)
	).call_deferred()

	var error = _request.request(url)
	if error != OK: 
		_error_message = "An error occurred while making the HTTP request: %d." % error

func _request_complete(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray):
	if result != HTTPRequest.RESULT_SUCCESS && response_code != HTTPClient.RESPONSE_OK:
		var error_message = "The HTTP request for the asset pack did not succeed. "
		match result:
			HTTPRequest.RESULT_CHUNKED_BODY_SIZE_MISMATCH:
				error_message += "Chunked body size mismatch."
			HTTPRequest.RESULT_CANT_CONNECT:
				error_message += "Request failed while connecting."
			HTTPRequest.RESULT_CANT_RESOLVE:
				error_message += "Request failed while resolving."
			HTTPRequest.RESULT_CONNECTION_ERROR:
				error_message += "Request failed due to connection (read/write) error."
			HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
				error_message += "Request failed on TSL handshake."
			HTTPRequest.RESULT_NO_RESPONSE:
				error_message += "No response."
			HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
				error_message += "Request exceeded its maximum body size limit."
			HTTPRequest.RESULT_REQUEST_FAILED:
				error_message += "Request failed."
			HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN:
				error_message += "HTTPRequest couldn't open the download file."
			HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR:
				error_message += "HTTPRequest couldn't write to the download file."
			HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED:
				error_message += "Request reached its maximum redirect limit."
			HTTPRequest.RESULT_TIMEOUT:
				error_message += "Request timed out."
			_:
				match response_code:
					HTTPClient.RESPONSE_NOT_FOUND:
						error_message += "Request failed due to invalid URL."
		_error_message = error_message
	
func _get_progress_string(downloaded_bytes: int, body_size: int, delta_time: int, delta_bytes: int) -> Array[String]:
	var amount_str = ""
	if (downloaded_bytes > 1024*1024): amount_str = "%.1f %s" % [(downloaded_bytes / 1048576.0), "MB"]
	else: amount_str = "%s %s" % [(downloaded_bytes / 1024.0), "KB"]

	var percent_str = ""
	if body_size > 0: percent_str = "%.1f%%" % ((float(downloaded_bytes) / body_size) * 100)

	var speed_str = ""
	var speed_bps = delta_bytes / float(delta_time) * 1000.0
	if speed_bps > 1048576.0: speed_str += "%.1f %s" % [(speed_bps / 1048576.0), "MB/s"]
	else: speed_str += "%d %s" % [(speed_bps / 1024.0), "KB/s"]

	return [amount_str, percent_str, speed_str]
	
func _thread_done(status: String, file_path: String):
	assert(status != "incomplete")
	# Always wait for threads to finish, this is required on Windows.
	_thread.wait_to_finish()
	call_deferred("emit_signal", "resource_loaded", file_path)

func _exit_tree():
	if _thread and _thread.is_alive():
		_thread.wait_to_finish()
