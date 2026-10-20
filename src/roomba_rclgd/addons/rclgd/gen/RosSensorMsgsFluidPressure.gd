extends RosMsg
class_name RosSensorMsgsFluidPressure

const ROS_TYPE_NAME = "sensor_msgs/msg/FluidPressure"

func _init():
	init(ROS_TYPE_NAME)

var header : RosStdMsgsHeader:
	get: return get_member(&"header")
	set(v): set_member(&"header", v)

var fluid_pressure : float:
	get: return get_member(&"fluid_pressure")
	set(v): set_member(&"fluid_pressure", v)

var variance : float:
	get: return get_member(&"variance")
	set(v): set_member(&"variance", v)

