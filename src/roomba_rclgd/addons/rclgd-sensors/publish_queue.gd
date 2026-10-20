extends RefCounted
## Publishes sensor captures off the main/render thread, strictly in capture order.
## GPU readbacks of consecutive captures overlap, but ROS consumers expect increasing stamps, so
## captures are queued and handed to `publish_fn` one at a time, oldest first, on one thread.
## The owner must call stop() before ROS shuts down or the owner is freed.

const MAX_QUEUED: int = 3 # If publishing falls this far behind, the oldest capture is dropped

var _publish_fn: Callable
var _queue: Array[Array] = [] # Argument lists for _publish_fn
var _stopping: bool = false
var _mutex := Mutex.new()
var _semaphore := Semaphore.new()
var _thread := Thread.new()

func _init(publish_fn: Callable) -> void:
	_publish_fn = publish_fn
	start()

## Starts the publishing thread, with an empty queue; does nothing if it is running
func start() -> void:
	if _thread.is_started():
		return
	_queue.clear()
	_stopping = false
	_thread.start(_run)

## Queues one capture; `args` are passed to publish_fn
func push(args: Array) -> void:
	_mutex.lock()
	if _queue.size() >= MAX_QUEUED:
		_queue.pop_front() # Its semaphore post is consumed by an empty pop in _run
	_queue.push_back(args)
	_mutex.unlock()
	_semaphore.post()

## Drops anything still queued and waits for the capture being published; does nothing if stopped
func stop() -> void:
	if not _thread.is_started():
		return
	_mutex.lock()
	_stopping = true
	_mutex.unlock()
	_semaphore.post()
	_thread.wait_to_finish()

func _run() -> void:
	while true:
		_semaphore.wait()
		_mutex.lock()
		var stopping := _stopping
		var args: Array = _queue.pop_front() if not _queue.is_empty() else []
		_mutex.unlock()
		if stopping:
			return
		if not args.is_empty():
			_publish_fn.callv(args)
