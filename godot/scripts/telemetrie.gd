class_name Telemetrie
extends RefCounted
## Lokale Telemetrie fürs Balancing. Nur wenn der Spieler sie in den Optionen einschaltet.
## Schreibt Zeilen (JSON) in eine Datei auf dem Gerät. Nichts wird versendet, keine Namen, keine Spieler-IDs.

const PATH := "user://einbruch_telemetrie.jsonl"


static func enabled() -> bool:
	var cfg := ConfigFile.new()
	return cfg.load("user://einbruch_optionen.cfg") == OK and bool(cfg.get_value("telemetrie", "an", false))


static func record(event: Dictionary) -> void:
	if not enabled():
		return
	var f := FileAccess.open(PATH, FileAccess.READ_WRITE if FileAccess.file_exists(PATH) else FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(JSON.stringify(event))


## Alle Zeilen als Text (zum Weitergeben an den Entwickler).
static func export_text() -> String:
	if not FileAccess.file_exists(PATH):
		return ""
	return FileAccess.open(PATH, FileAccess.READ).get_as_text()


static func clear() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)
