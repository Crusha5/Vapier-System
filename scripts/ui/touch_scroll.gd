class_name TouchScroll
extends Node
## Zuverlässiges Wischen in Listen: übernimmt das Scrollen eines ScrollContainers
## selbst (vor der GUI), mit Schwelle und Schwung. Nach einem Wisch werden
## Knopfdrücke kurz unterdrückt, damit beim Scrollen nichts ausgelöst wird.

const THRESHOLD := 10.0

static var suppress_until := 0
static var dragging_any := false

var sc: ScrollContainer
var horizontal := false
var _idx := -1
var _start := Vector2.ZERO
var _last := Vector2.ZERO
var _start_scroll := 0.0
var _drag := false
var _vel := 0.0
var _last_t := 0
var _pos := 0.0

static func attach(s: ScrollContainer, horiz := false) -> TouchScroll:
	var t := TouchScroll.new()
	t.sc = s
	t.horizontal = horiz
	s.scroll_deadzone = 100000
	s.add_child(t, false, Node.INTERNAL_MODE_FRONT)
	return t

## true, wenn ein Tippen gerade als echter Tipp gilt (kein Wischen)
static func tap_ok() -> bool:
	return not dragging_any and Time.get_ticks_msec() >= suppress_until

func _visible() -> bool:
	return is_instance_valid(sc) and sc.is_visible_in_tree()

func _bar_max() -> float:
	if horizontal:
		return maxf(0.0, sc.get_h_scroll_bar().max_value - sc.size.x)
	return maxf(0.0, sc.get_v_scroll_bar().max_value - sc.size.y)

func _set_pos(v: float) -> void:
	_pos = clampf(v, 0.0, _bar_max())
	if horizontal:
		sc.scroll_horizontal = int(round(_pos))
	else:
		sc.scroll_vertical = int(round(_pos))

func _axis(v: Vector2) -> float:
	return v.x if horizontal else v.y

func _input(event: InputEvent) -> void:
	if not _visible():
		_idx = -1
		return
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			if _idx < 0 and sc.get_global_rect().has_point(e.position) and _bar_max() > 0.0:
				_idx = e.index
				_start = e.position
				_last = e.position
				_start_scroll = sc.scroll_horizontal if horizontal else sc.scroll_vertical
				_pos = _start_scroll
				_drag = false
				_vel = 0.0
				_last_t = Time.get_ticks_usec()
		elif e.index == _idx:
			_idx = -1
			if Time.get_ticks_usec() - _last_t > 80000:
				_vel = 0.0
			if _drag:
				_drag = false
				dragging_any = false
				suppress_until = Time.get_ticks_msec() + 180
	elif event is InputEventScreenDrag:
		var e := event as InputEventScreenDrag
		if e.index != _idx:
			return
		var moved := _axis(e.position - _start)
		if not _drag:
			if absf(moved) > THRESHOLD:
				_drag = true
				dragging_any = true
				_start = e.position
				_last = e.position
				_start_scroll = _pos
			else:
				return
		var now := Time.get_ticks_usec()
		var dt := maxf(0.001, float(now - _last_t) / 1000000.0)
		var d := _axis(e.position - _last)
		_vel = lerpf(_vel, -d / dt, 0.4)
		_last_t = now
		_last = e.position
		_set_pos(_start_scroll - _axis(e.position - _start))
		suppress_until = Time.get_ticks_msec() + 180

func _process(dt: float) -> void:
	if _idx >= 0 or not _visible():
		return
	if absf(_vel) < 20.0:
		_vel = 0.0
		return
	_set_pos(_pos + _vel * dt)
	_vel *= pow(0.04, dt)
	if _pos <= 0.0 or _pos >= _bar_max():
		_vel = 0.0
