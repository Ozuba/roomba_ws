extends RosMsg
class_name RosSensorMsgsRegionOfInterest

const ROS_TYPE_NAME = "sensor_msgs/msg/RegionOfInterest"

func _init():
	init(ROS_TYPE_NAME)

var x_offset : int:
	get: return get_member(&"x_offset")
	set(v): set_member(&"x_offset", v)

var y_offset : int:
	get: return get_member(&"y_offset")
	set(v): set_member(&"y_offset", v)

var height : int:
	get: return get_member(&"height")
	set(v): set_member(&"height", v)

var width : int:
	get: return get_member(&"width")
	set(v): set_member(&"width", v)

var do_rectify : bool:
	get: return get_member(&"do_rectify")
	set(v): set_member(&"do_rectify", v)

