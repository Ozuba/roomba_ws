extends RosMsg
class_name RosTurtlesimPose

const ROS_TYPE_NAME = "turtlesim/msg/Pose"

func _init():
	init(ROS_TYPE_NAME)

var x : float:
	get: return get_member(&"x")
	set(v): set_member(&"x", v)

var y : float:
	get: return get_member(&"y")
	set(v): set_member(&"y", v)

var theta : float:
	get: return get_member(&"theta")
	set(v): set_member(&"theta", v)

var linear_velocity : float:
	get: return get_member(&"linear_velocity")
	set(v): set_member(&"linear_velocity", v)

var angular_velocity : float:
	get: return get_member(&"angular_velocity")
	set(v): set_member(&"angular_velocity", v)

