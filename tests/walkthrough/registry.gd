extends RefCounted
## The one list every surface of the walkthrough reads (ADR-031).
##
## QM's walkthrough record asks for one registry and no hand-maintained list
## beside it: the index, the page filenames, the shot filenames and the
## "every suite has a page" check all read this array, so a rename cannot
## desynchronise them -- there is one name. The order here is the order a
## newcomer reads the pages in, which is roughly the order the game is met in:
## what you see, what you hold, how it flies, who is against you, what is
## written down. Not alphabetical, on purpose.
##
## Adding a suite under `tests/` without a row here fails
## `test_walkthrough.gd`; so does a row whose suite is not there. Declaring a
## shot here that no test records fails it too: a shot's name is the filename
## the recording test writes and the filename the page embeds, and the
## registry is where the two are promised to agree.
##
## `id` becomes the page's slug and the shots' directory; the ordinal is the
## row's position, so reordering renumbers the pages and moves no picture.

const PAGES: Array[Dictionary] = [
	{
		"id": "the-first-thing-you-see",
		"title": "The first thing you see",
		"suite": "res://tests/ui/test_first_run.gd",
		"shots": {
			"opens-on-defence": "The first frame. The game's golfer is at the ball; the bow is yours; the switch in the corner hands you the club.",
		},
	},
	{
		"id": "the-club-selector",
		"title": "The club selector",
		"suite": "res://tests/ui/test_club_selector.gd",
		"shots": {
			"the-corner": "The selector, fully faded up in its corner, before any stroke has been taken.",
		},
	},
	{
		"id": "the-stroke",
		"title": "The stroke",
		"suite": "res://tests/stroke/test_stroke_gesture.gd",
		"shots": {},
	},
	{
		"id": "the-aim-ribbon",
		"title": "The aim ribbon",
		"suite": "res://tests/stroke/test_aim_ribbon.gd",
		"shots": {},
	},
	{
		"id": "ball-flight",
		"title": "Ball flight",
		"suite": "res://tests/stroke/test_ball_flight.gd",
		"shots": {},
	},
	{
		"id": "three-clubs",
		"title": "Three clubs",
		"suite": "res://tests/stroke/test_club_profile.gd",
		"shots": {},
	},
	{
		"id": "the-camera",
		"title": "The camera",
		"suite": "res://tests/camera/test_camera_orbit.gd",
		"shots": {},
	},
	{
		"id": "the-range",
		"title": "The range",
		"suite": "res://tests/holes/test_practice_range.gd",
		"shots": {
			"the-range": "The range on its own, as the suite instantiates it: three pins, the mat, the archer's rock.",
		},
	},
	{
		"id": "defenders",
		"title": "Defenders, and what is fair",
		"suite": "res://tests/defenders/test_defender_brain.gd",
		"shots": {},
	},
	{
		"id": "the-archer",
		"title": "The archer",
		"suite": "res://tests/defenders/test_archer_brain.gd",
		"shots": {},
	},
	{
		"id": "stroke-records",
		"title": "Stroke records",
		"suite": "res://tests/records/test_stroke_record.gd",
		"shots": {},
	},
	{
		"id": "the-record-schema",
		"title": "The record schema",
		"suite": "res://tests/records/test_record_schema.gd",
		"shots": {},
	},
	{
		"id": "canonical-bytes",
		"title": "Canonical bytes",
		"suite": "res://tests/records/test_canonical.gd",
		"shots": {},
	},
	{
		"id": "physics-guarantees",
		"title": "Physics guarantees",
		"suite": "res://tests/core/test_physics_guarantees.gd",
		"shots": {},
	},
	{
		"id": "the-harness",
		"title": "The harness and the pin",
		"suite": "res://tests/test_bootstrap.gd",
		"shots": {},
	},
	{
		"id": "how-this-walkthrough-is-made",
		"title": "How this walkthrough is made",
		"suite": "res://tests/walkthrough/test_walkthrough.gd",
		"shots": {},
	},
]
