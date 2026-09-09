extends Node
## The menu screen. Its background state is the practice range, live and
## playable.
##
## There are no buttons here during a first run, on purpose. Pillar 3 says
## nothing should stand between the urge to play and the first swing, so the
## first thing a new player sees is a ball on a mat and a ghost showing them the
## stroke. Touching the screen does not open the game -- it *is* the first
## stroke.
##
## This node owns only the flat layer: the ghost demonstration and the card.
## The range owns the golf.

const GHOST_DELAY := 0.9

var range_: Node3D
var _ghost: GhostGesture
var _scorecard: Scorecard
var _clubs: ClubSelector
var _taught := {}
var _idle := 0.0
var _player_acted := false


func _ready() -> void:
	range_ = get_node("PracticeRange")

	var layer := CanvasLayer.new()
	add_child(layer)

	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	# The overlay itself passes touches through; only the selector inside it
	# stops them.
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(overlay)

	_ghost = GhostGesture.new()
	_ghost.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(_ghost)

	_scorecard = Scorecard.new()
	_scorecard.set_anchors_preset(Control.PRESET_FULL_RECT)
	# One ring per pin, filled as each is made. A range is not scored against
	# par: you are done with a pin when you have put a ball on it, and how many
	# it took is counted but never held against you.
	_scorecard.par = range_.PINS.size()
	overlay.add_child(_scorecard)

	# The one control in the game. It is a Control rather than world geometry so
	# that a tap landing on it is marked handled and never reaches StrokeGesture,
	# which listens on _unhandled_input -- no rectangle checks and no special
	# case in the gesture.
	# No anchor preset here: the selector pins itself into the top-left corner in
	# its own _ready. Giving it a full-rect preset first is what left it covering
	# the whole screen and eating every press.
	_clubs = ClubSelector.new()
	overlay.add_child(_clubs)
	_clubs.club_chosen.connect(_on_club_chosen)
	_clubs.selected = range_.club_index

	range_.club_changed.connect(_on_club_changed)
	range_.stroke_began.connect(_on_stroke_began)
	range_.pin_changed.connect(_on_pin_changed)
	range_.stroke_taken.connect(_on_stroke_taken)
	range_.pin_made.connect(_on_pin_made)
	_on_pin_changed(range_.pin)


func _process(delta: float) -> void:
	# The ghost is pinned to the ball on screen, not parked in the corner: the
	# demonstration happens where the player has to act.
	_ghost.anchor = range_.camera.unproject_position(range_.ball.global_position)

	var aiming: bool = range_.state == range_.State.AIM or range_.state == range_.State.ATTRACT
	if aiming and not _taught.get(range_.pin, false):
		_idle += delta
		if _idle > GHOST_DELAY:
			_ghost.resume()
	else:
		_ghost.suppress()

	# The live scorecard fades up once the player has actually done something,
	# so an untouched attract screen stays clean.
	var want: float = 1.0 if _player_acted else 0.0
	_scorecard.shown = move_toward(_scorecard.shown, want, delta * 2.0)
	# The selector is up from the first frame, unlike the card. It is not a menu
	# standing between the player and the first swing -- it is part of the range,
	# and a player who cannot see what is in their hands until after they have
	# swung has been told nothing. Hiding it also made it unfindable while it was
	# still, invisibly, consuming every tap.
	_clubs.shown = move_toward(_clubs.shown, 1.0, delta * 2.5)


func _unhandled_input(event: InputEvent) -> void:
	var pressed := (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed) \
		or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed)
	if pressed and range_.state == range_.State.DONE:
		_restart()


## The moment the player takes over, the demo stops competing with them. This
## arrives as a signal rather than as raw input, because StrokeGesture marks the
## press handled and nothing downstream of it ever sees the event.
func _on_stroke_began() -> void:
	_ghost.suppress()
	_idle = 0.0


## A new pin means a new club, and the ghost demonstrates the stroke once more.
## The gesture has not changed, but what it produces has -- a player who has only
## ever swung a wedge has not yet seen what the same drag does with a driver.
func _on_pin_changed(_index: int) -> void:
	_idle = 0.0
	_ghost.suppress()
	_ghost.pattern = GhostGesture.Pattern.PULL


func _on_stroke_taken(strokes: int) -> void:
	_player_acted = true
	# A pin is demonstrated once. Having taken a swing at it, the player is not
	# shown the ghost again -- a demo that keeps replaying after it has landed
	# reads as nagging.
	_taught[range_.pin] = true


## The player reached for a different club. The range is the one that decides
## what that means; this only asks.
func _on_club_chosen(index: int) -> void:
	range_.set_club(index)


## And the range answering -- either because the player asked, or because a new
## pin came up and handed them the club it suggests.
func _on_club_changed(index: int) -> void:
	_clubs.selected = index


## The card counts pins made, not strokes taken.
func _on_pin_made(index: int, _holed: bool) -> void:
	_scorecard.strokes = index + 1


func _restart() -> void:
	get_tree().reload_current_scene()
