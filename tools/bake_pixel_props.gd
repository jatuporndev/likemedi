@tool
extends EditorScript

const PixelPropsScript = preload("res://scripts/world/pixel_props.gd")


func _run() -> void:
	if not DirAccess.dir_exists_absolute(PixelPropsScript.PNG_DIR):
		DirAccess.make_dir_recursive_absolute(PixelPropsScript.PNG_DIR)

	var count := 0
	for kind in PixelPropsScript.KINDS:
		for variant in range(PixelPropsScript.VARIANTS):
			var img: Image = PixelPropsScript.generate_image(kind, variant)
			var path := "%s%s_%d.png" % [PixelPropsScript.PNG_DIR, kind, variant]
			var err := img.save_png(path)
			if err == OK:
				print("Baked %s" % path)
				count += 1
			else:
				push_error("Failed to save %s (err %d)" % [path, err])

	print("PixelProps: baked %d sprites to %s" % [count, PixelPropsScript.PNG_DIR])
	print("Refresh the FileSystem dock to import them.")
