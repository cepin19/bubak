extends Node2D
## A piece of furniture, toy or care item standing on the floor.
## The node's position is the bottom-centre of the sprite (where it touches the floor).

var id := ""
var uid := 0          # 0 = fixed part of the apartment, not saved/movable
var movable := true
var sprite: Sprite2D
var tex_name := ""
var item_scale := 1.0
var shadow := true
const NO_SHADOW := ["door", "balcony_door", "cable", "sunspot", "trophy_shelf"]


func setup(item_id: String, item_uid: int, texture_name := "", s := -1.0) -> void:
	id = item_id
	uid = item_uid
	var info: Dictionary = Catalog.ITEMS.get(id, {})
	item_scale = s if s > 0 else info.get("scale", 1.0)
	sprite = Sprite2D.new()
	sprite.centered = false
	add_child(sprite)
	set_texture(texture_name if texture_name != "" else info.get("tex", id))
	shadow = not info.get("flat", false) and not id in NO_SHADOW


func _ready() -> void:
	if id in ["plant", "flowers", "planter"]:
		# leaves sway gently, each plant at its own pace
		var t := create_tween().set_loops()
		t.tween_interval(randf() * 1.5)
		t.tween_property(sprite, "skew", 0.035, randf_range(1.8, 2.6)).set_trans(Tween.TRANS_SINE)
		t.tween_property(sprite, "skew", -0.035, randf_range(1.8, 2.6)).set_trans(Tween.TRANS_SINE)


func set_texture(name: String) -> void:
	if name == tex_name:
		return
	tex_name = name
	sprite.texture = Catalog.tex(name)
	var size := sprite.texture.get_size()
	sprite.offset = Vector2(-size.x / 2.0, -size.y)
	sprite.scale = Vector2.ONE * item_scale
	queue_redraw()


## Soft contact shadow under the item.
func _draw() -> void:
	if not shadow or sprite.texture == null:
		return
	var w := size().x * 0.95
	draw_texture_rect(Catalog.soft_circle(), Rect2(-w / 2.0, -w * 0.1 - 2, w, w * 0.2), false, Color(0.28, 0.16, 0.1, 0.32))


func size() -> Vector2:
	return sprite.texture.get_size() * item_scale


func rect() -> Rect2:
	var s := size()
	return Rect2(position + Vector2(-s.x / 2.0, -s.y), s)


## Where Bubák stands to use this item.
func use_point(from: Vector2) -> Vector2:
	var s := size()
	match id:
		"litter", "bed":
			return position + Vector2(0, 2)
		"box", "hut", "digbox", "castle":
			return position + Vector2(0, 4)
		"tunnel":
			return position + Vector2(-s.x / 2.0 + 20, 4)
		"desk", "sofa":
			return position + Vector2(randf_range(-s.x / 3.0, s.x / 3.0), 20)
		"cable":
			return position + Vector2(0, 26)
		"door", "balcony_door":
			return position + Vector2(0, 52)
	var side := -1.0 if from.x < position.x else 1.0
	return position + Vector2(side * (s.x / 2.0 + 34), 6)


func wiggle(strength := 1.0) -> void:
	var t := create_tween()
	t.tween_property(sprite, "rotation", 0.06 * strength, 0.07)
	t.tween_property(sprite, "rotation", -0.06 * strength, 0.1)
	t.tween_property(sprite, "rotation", 0.0, 0.07)
	var t2 := create_tween()
	t2.tween_property(sprite, "scale", Vector2(item_scale * 1.06, item_scale * 0.94), 0.08)
	t2.tween_property(sprite, "scale", Vector2.ONE * item_scale, 0.15).set_trans(Tween.TRANS_BACK)


func set_highlight(on: bool) -> void:
	sprite.modulate = Color(1.15, 1.1, 0.9) if on else Color.WHITE
