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
## **One exception, and it is committed.** The boot splash. Godot reads
## `boot_splash/image` as a raw file at startup and only accepts PNG -- the
## error, verbatim, is "The only supported format is PNG" -- so it cannot stay
## SVG the way the icons do. It is rendered here from the same source, checked
## in at `art/icon/boot_splash.png`, and exempted from LFS in `.gitattributes`
## the way `addons/` is: an LFS pointer file sitting where Godot expects a PNG
## would put Godot's own splash back on every fresh clone, which is the exact
## thing ADR-025 removed. Re-run this after touching `icon.svg` and commit the
## result; a splash that has quietly stopped matching its source is the same
## bug as an icon that has.
##
##   godot --headless --path . --script tools/make_icons.gd

const SIZES := {
	"icon.svg": [16, 24, 32, 48, 64, 128, 256],
	"art/icon/adaptive_foreground.svg": [432],
	"art/icon/adaptive_background.svg": [432],
}

const OUT := "build/icons"

## Source -> committed destination, and the size. 1024 because the splash is
## scaled to fit the window (`boot_splash/fullsize`), and a phone held sideways
## is 1080 tall; anything smaller is upscaled and goes soft.
const COMMITTED := {
	"icon.svg": ["art/icon/boot_splash.png", 1024],
}


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

	for source in COMMITTED:
		var dest: String = COMMITTED[source][0]
		var size: int = COMMITTED[source][1]
		var svg: String = FileAccess.get_file_as_string(source)
		var image := Image.new()
		if image.load_svg_from_string(svg, float(size) / 128.0) != OK:
			push_error("could not rasterise %s" % source)
			quit(1)
			return
		image.resize(size, size, Image.INTERPOLATE_LANCZOS)
		image.save_png(dest)
		print("  %s  %dx%d  (committed -- see the header)" % [dest, size, size])
	quit(0)
