extends Label

var fps_bool := false
var ping_bool := false
var death_count: int = 0

func _process(_delta: float) -> void:
	var fps: String = "FPS " + str(Engine.get_frames_per_second()) + "\n" if fps_bool else ""
	var ping: String = "PING " + str(ENetPacketPeer.PeerStatistic.PEER_ROUND_TRIP_TIME) + "\n" if ping_bool else ""
	var deaths: String = "Deaths: " + str(death_count)  # Show death count
	
	text = fps + ping + deaths

func _on_fps_counter_toggled(toggled_on: bool) -> void:
	fps_bool = toggled_on

func _on_ping_toggled(toggled_on: bool) -> void:
	ping_bool = toggled_on

func update_death_count(new_death_count: int) -> void:
	death_count = new_death_count
