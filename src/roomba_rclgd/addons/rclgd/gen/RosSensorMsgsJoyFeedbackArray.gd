extends RosMsg
class_name RosSensorMsgsJoyFeedbackArray

const ROS_TYPE_NAME = "sensor_msgs/msg/JoyFeedbackArray"

func _init():
	init(ROS_TYPE_NAME)

var array : Array[RosSensorMsgsJoyFeedback]:
	get: return get_member(&"array")
	set(v): set_member(&"array", v)

