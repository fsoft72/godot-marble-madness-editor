class_name PlayerHud
extends CanvasLayer
## Player overlay: time and falls, a centered message and the control hints.

const FONT_SIZE := 20
const MESSAGE_FONT_SIZE := 44
const MARGIN := 16.0
## Black outline keeps the text readable over the level.
const OUTLINE_SIZE := 6
const SECONDS_PER_MINUTE := 60

var _status := Label.new()
var _message := Label.new()
var _hints := Label.new()


## Builds the labels; hints mention the way back to the editor only when there is one.
func _init(from_editor: bool = false) -> void:
	name = "PlayerHud"
	_status.name = "Status"
	_status.add_theme_font_size_override("font_size", FONT_SIZE)
	_status.position = Vector2(MARGIN, MARGIN)
	add_child(_status)
	_message.name = "Message"
	_message.add_theme_font_size_override("font_size", MESSAGE_FONT_SIZE)
	_message.set_anchors_preset(Control.PRESET_FULL_RECT)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_message)
	_hints.name = "Hints"
	_hints.add_theme_font_size_override("font_size", FONT_SIZE)
	_hints.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hints.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hints.position.x = MARGIN
	_hints.offset_top = -MARGIN
	_hints.offset_bottom = -MARGIN
	_hints.text = I18n.t("play_hints")
	if from_editor: _hints.text += "  " + I18n.t("play_hint_exit")
	add_child(_hints)
	for label in [_status, _hints]: label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for label in [_status, _message, _hints]:
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", OUTLINE_SIZE)


## Shows the elapsed time and the number of falls.
func set_status(seconds: float, falls: int) -> void:
	_status.text = "%s  %s %d" % [format_time(seconds), I18n.t("play_falls"), falls]


## Shows a centered message; an empty text hides it.
func set_message(text: String) -> void:
	_message.text = text


## Returns the centered message.
func message() -> String:
	return _message.text


## Formats seconds as m:ss.t.
static func format_time(seconds: float) -> String:
	var tenths := int(seconds * 10.0)
	var whole := tenths / 10
	return "%d:%02d.%d" % [whole / SECONDS_PER_MINUTE, whole % SECONDS_PER_MINUTE, tenths % 10]
