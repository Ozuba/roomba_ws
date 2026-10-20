extends RosMsg
class_name RosSensorMsgsLaserEcho

const ROS_TYPE_NAME = "sensor_msgs/msg/LaserEcho"

func _init():
	init(ROS_TYPE_NAME)

var echoes : PackedFloat32Array:
	get: return get_member(&"echoes")
	set(v): set_member(&"echoes", v)

