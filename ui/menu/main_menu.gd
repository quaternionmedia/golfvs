extends Node
## The menu screen. Its background state is the intro hole, live and playable.
##
## There are no buttons here during a first run, on purpose. Pillar 3 says
## nothing should stand between the urge to play and the first swing, so the
## first thing a new player sees is a golf hole with a ball on the tee and a
## ghost showing them the stroke. Touching the screen does not open the game --
## it *is* the first stroke.
##
## This node owns only the flat layer: the ghost demonstration and the
## scorecard. The hole owns the golf.

const GHOST_DELAY := 0.9

var hole: Node3D
var _ghost: GhostGesture
var _scorecard: Scorecard
var _taught := {}
var _idle := 0.0
var _player_acted := false


func _ready() -> void:
	hole = get_node("IntroHole")

	var layer := CanvasLayer.new()
	add_child(layer)

	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(overlay)

	_ghost = GhostGesture.new()
	_ghost.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(_ghost)

	_scorecard = Scorecard.new()
	_scorecard.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scorecard.par = hole.PAR
	overlay.add_child(_scorecard)

	hole.stroke_began.connect(_on_stroke_began)
	hole.lesson_changed.connect(_on_lesson_changed)
	hole.stroke_taken.connect(_on_stroke_taken)
	hole.holed.connect(_on_holed)
	_on_lesson_changed(hole.lesson)


func _process(delta: float) -> void:
	# The ghost is pinned to the ball on screen, not parked in the corner: the
	# demonstration happens where the player has to act.
	_ghost.anchor = hole.camera.unproject_position(hole.ball.global_position)

	var aiming: bool = hole.state == hole.State.AIM or hole.state == hole.State.ATTRACT
	if aiming and not _taught.get(hole.lesson, false):
		_idle += delta
		if _idle > GHOST_DELAY:
			_ghost.resume()
	else:
		_ghost.suppress()

	# The live scorecard fades up once the player has actually done something,
	# so an untouched attract screen stays clean.
	var want: float = 1.0 if _player_acted else 0.0
	_scorecard.shown = move_toward(_scorecard.shown, want, delta * 2.0)


func _unhandled_input(event: InputEvent) -> void:
	var pressed := (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed) \
		or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed)
	if pressed and hole.state == hole.State.HOLED:
		_restart()


## The moment the player takes over, the demo stops competing with them. This
## arrives as a signal rather than as raw input, because StrokeGesture marks the
## press handled and nothing downstream of it ever sees the event.
func _on_stroke_began() -> void:
	_ghost.suppress()
	_idle = 0.0


func _on_lesson_changed(lesson: int) -> void:
	_idle = 0.0
	_ghost.suppress()
	_ghost.pattern = GhostGesture.Pattern.PULL_CURVE if lesson == hole.Lesson.CURVE \
		else GhostGesture.Pattern.PULL


func _on_stroke_taken(strokes: int) -> void:
	_player_acted = true
	# A lesson is taught once. Having done the thing, the player is not shown it
	# again -- a demo that keeps replaying after it has landed reads as nagging.
	_taught[hole.lesson] = true
	_scorecard.strokes = strokes


func _on_holed(strokes: int) -> void:
	_scorecard.strokes = strokes


func _restart() -> void:
	get_tree().reload_current_scene()
