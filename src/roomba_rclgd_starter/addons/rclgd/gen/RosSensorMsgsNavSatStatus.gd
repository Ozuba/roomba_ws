extends RosMsg
class_name RosSensorMsgsNavSatStatus

const ROS_TYPE_NAME = "sensor_msgs/msg/NavSatStatus"

func _init():
	init(ROS_TYPE_NAME)

var status : int:
	get: return get_member(&"status")
	set(v): set_member(&"status", v)

var service : int:
	get: return get_member(&"service")
	set(v): set_member(&"service", v)

