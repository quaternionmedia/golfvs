extends SceneTree
## Render the SVG icons to PNG, at the sizes each platform asks for.
##
## Godot is the renderer because Godot is already pinned (ADR-008) and its SVG
## rasteriser is the one that will draw these in-engine anyway. Adding a second
## one -- rsvg, Inkscape, a Python library -- would mean the icon in the editor
## and the icon on the phone came out of different code.
##
## The PNGs are build output, not sources. `*.png` is LFS-tracked here
## (`.gitattributes`), and the LFS path has never been proven end to end, so the
## icons stay SVG in the repository and become PNG only on the way out.
##
##   godot --headless --path . --script tools/make_icons.gd

const SIZES := {
	"icon.svg": [16, 24, 32, 48, 64, 128, 256],
	"art/icon/adaptive_foreground.svg": [432],
	"art/icon/adaptive_background.svg": [432],
}

const OUT := "build/icons"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	for source in SIZES:
		if not FileAccess.file_exists(source):
			push_error("missing %s" % source)
			quit(1)
			return
		var svg: String = FileAccess.get_file_as_string(source)
		var stem: String = source.get_file().get_basename()
		for size: int in SIZES[source]:
			var image := Image.new()
			# The rasteriser takes a scale rather than a size, and the sources
			# are authored at 128 CSS pixels.
			if image.load_svg_from_string(svg, float(size) / 128.0) != OK:
				push_error("could not rasterise %s" % source)
				quit(1)
				return
			image.resize(size, size, Image.INTERPOLATE_LANCZOS)
			var path := "%s/%s_%d.png" % [OUT, stem, size]
			image.save_png(path)
			print("  %s  %dx%d" % [path, size, size])
	print("icons written to %s/" % OUT)
	quit(0)
