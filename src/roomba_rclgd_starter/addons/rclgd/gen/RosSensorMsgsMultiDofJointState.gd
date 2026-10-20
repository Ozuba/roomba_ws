extends RosMsg
class_name RosSensorMsgsMultiDofJointState

const ROS_TYPE_NAME = "sensor_msgs/msg/MultiDOFJointState"

func _init():
	init(ROS_TYPE_NAME)

var header : RosStdMsgsHeader:
	get: return get_member(&"header")
	set(v): set_member(&"header", v)

var joint_names : PackedStringArray:
	get: return get_member(&"joint_names")
	set(v): set_member(&"joint_names", v)

var transforms : Array[RosGeometryMsgsTransform]:
	get: return get_member(&"transforms")
	set(v): set_member(&"transforms", v)

var twist : Array[RosGeometryMsgsTwist]:
	get: return get_member(&"twist")
	set(v): set_member(&"twist", v)

var wrench : Array[RosGeometryMsgsWrench]:
	get: return get_member(&"wrench")
	set(v): set_member(&"wrench", v)

