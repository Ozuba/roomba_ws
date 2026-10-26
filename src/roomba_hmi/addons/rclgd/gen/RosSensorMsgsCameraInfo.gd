extends RosMsg
class_name RosSensorMsgsCameraInfo

const ROS_TYPE_NAME = "sensor_msgs/msg/CameraInfo"

func _init():
	init(ROS_TYPE_NAME)

var header : RosStdMsgsHeader:
	get: return get_member(&"header")
	set(v): set_member(&"header", v)

var height : int:
	get: return get_member(&"height")
	set(v): set_member(&"height", v)

var width : int:
	get: return get_member(&"width")
	set(v): set_member(&"width", v)

var distortion_model : String:
	get: return get_member(&"distortion_model")
	set(v): set_member(&"distortion_model", v)

var d : PackedFloat64Array:
	get: return get_member(&"d")
	set(v): set_member(&"d", v)

var k : PackedFloat64Array:
	get: return get_member(&"k")
	set(v): set_member(&"k", v)

var r : PackedFloat64Array:
	get: return get_member(&"r")
	set(v): set_member(&"r", v)

var p : PackedFloat64Array:
	get: return get_member(&"p")
	set(v): set_member(&"p", v)

var binning_x : int:
	get: return get_member(&"binning_x")
	set(v): set_member(&"binning_x", v)

var binning_y : int:
	get: return get_member(&"binning_y")
	set(v): set_member(&"binning_y", v)

var roi : RosSensorMsgsRegionOfInterest:
	get: return get_member(&"roi")
	set(v): set_member(&"roi", v)

