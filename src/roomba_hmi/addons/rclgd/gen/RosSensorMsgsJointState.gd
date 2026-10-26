extends RosMsg
class_name RosSensorMsgsJointState

const ROS_TYPE_NAME = "sensor_msgs/msg/JointState"

func _init():
	init(ROS_TYPE_NAME)

var header : RosStdMsgsHeader:
	get: return get_member(&"header")
	set(v): set_member(&"header", v)

var name : PackedStringArray:
	get: return get_member(&"name")
	set(v): set_member(&"name", v)

var position : PackedFloat64Array:
	get: return get_member(&"position")
	set(v): set_member(&"position", v)

var velocity : PackedFloat64Array:
	get: return get_member(&"velocity")
	set(v): set_member(&"velocity", v)

var effort : PackedFloat64Array:
	get: return get_member(&"effort")
	set(v): set_member(&"effort", v)

