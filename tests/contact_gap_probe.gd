extends SceneTree
func _initialize() -> void:
 var config: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/250f.json"))
 var station=load("res://src/physics/replacement/wheel_station.gd")
 var outputs: Array=[]
 for contact in [false,true]:
  var wheel=station.new(0)
  wheel.compression=0.1
  wheel.velocity=-0.1
  wheel.step(1.0/960,-0.2,1.0,1.0,-9.81,config,contact)
  outputs.append({"ray_hit":contact,"compression_m":wheel.compression,"velocity_m_s":wheel.velocity,"load_n":wheel.load})
 FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE).store_string(JSON.stringify(outputs))
 print("CONTACT_GAP ",JSON.stringify(outputs))
 quit()
