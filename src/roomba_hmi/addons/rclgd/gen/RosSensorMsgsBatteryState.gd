extends RosMsg
class_name RosSensorMsgsBatteryState

const ROS_TYPE_NAME = "sensor_msgs/msg/BatteryState"

func _init():
	init(ROS_TYPE_NAME)

var header : RosStdMsgsHeader:
	get: return get_member(&"header")
	set(v): set_member(&"header", v)

var voltage : float:
	get: return get_member(&"voltage")
	set(v): set_member(&"voltage", v)

var temperature : float:
	get: return get_member(&"temperature")
	set(v): set_member(&"temperature", v)

var current : float:
	get: return get_member(&"current")
	set(v): set_member(&"current", v)

var charge : float:
	get: return get_member(&"charge")
	set(v): set_member(&"charge", v)

var capacity : float:
	get: return get_member(&"capacity")
	set(v): set_member(&"capacity", v)

var design_capacity : float:
	get: return get_member(&"design_capacity")
	set(v): set_member(&"design_capacity", v)

var percentage : float:
	get: return get_member(&"percentage")
	set(v): set_member(&"percentage", v)

var power_supply_status : int:
	get: return get_member(&"power_supply_status")
	set(v): set_member(&"power_supply_status", v)

var power_supply_health : int:
	get: return get_member(&"power_supply_health")
	set(v): set_member(&"power_supply_health", v)

var power_supply_technology : int:
	get: return get_member(&"power_supply_technology")
	set(v): set_member(&"power_supply_technology", v)

var present : bool:
	get: return get_member(&"present")
	set(v): set_member(&"present", v)

var cell_voltage : PackedFloat32Array:
	get: return get_member(&"cell_voltage")
	set(v): set_member(&"cell_voltage", v)

var cell_temperature : PackedFloat32Array:
	get: return get_member(&"cell_temperature")
	set(v): set_member(&"cell_temperature", v)

var location : String:
	get: return get_member(&"location")
	set(v): set_member(&"location", v)

var serial_number : String:
	get: return get_member(&"serial_number")
	set(v): set_member(&"serial_number", v)

