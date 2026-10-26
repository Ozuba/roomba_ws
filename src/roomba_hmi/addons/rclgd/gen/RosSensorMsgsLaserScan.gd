extends RosMsg
class_name RosSensorMsgsLaserScan

const ROS_TYPE_NAME = "sensor_msgs/msg/LaserScan"

func _init():
	init(ROS_TYPE_NAME)

var header : RosStdMsgsHeader:
	get: return get_member(&"header")
	set(v): set_member(&"header", v)

var angle_min : float:
	get: return get_member(&"angle_min")
	set(v): set_member(&"angle_min", v)

var angle_max : float:
	get: return get_member(&"angle_max")
	set(v): set_member(&"angle_max", v)

var angle_increment : float:
	get: return get_member(&"angle_increment")
	set(v): set_member(&"angle_increment", v)

var time_increment : float:
	get: return get_member(&"time_increment")
	set(v): set_member(&"time_increment", v)

var scan_time : float:
	get: return get_member(&"scan_time")
	set(v): set_member(&"scan_time", v)

var range_min : float:
	get: return get_member(&"range_min")
	set(v): set_member(&"range_min", v)

var range_max : float:
	get: return get_member(&"range_max")
	set(v): set_member(&"range_max", v)

var ranges : PackedFloat32Array:
	get: return get_member(&"ranges")
	set(v): set_member(&"ranges", v)

var intensities : PackedFloat32Array:
	get: return get_member(&"intensities")
	set(v): set_member(&"intensities", v)

