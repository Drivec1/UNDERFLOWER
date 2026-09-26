extends Sprite2D

@export var 半径: float = 100.0        # ∞ 形大小
@export var 循环速度: float = 0.4      # 每秒走完整圈的百分比

@export_group("非线性设置")
@export var 启用非线性: bool = true:
	set(value):
		启用非线性 = value
		notify_property_list_changed()

@export_range(0.1, 5.0, 0.1) var 路径缓动: float = 1.0
@export var 中心点停顿: bool = true

@export_group("曲线平滑度")
@export_range(0.1, 1.0, 0.05) var 圆滑度: float = 0.4

@export_group("残影设置")
@export var 启用残影: bool = true
@export var 残影间隔: float = 0.05        # 多少秒生成一个残影，越小越密
@export var 残影存活时间: float = 0.6      # 残影淡出时间
@export_range(0.0, 1.0, 0.05) var 残影初始不透明度: float = 0.7
@export_range(0.3, 1.0, 0.05) var 残影缩小比例: float = 0.85  # 消失时缩小到原大小的比例
@export var 彩虹变化速度: float = 1.5      # 每个残影之间色相的变化量
@export_range(0.0, 1.0, 0.05) var 彩虹饱和度: float = 0.9

var 原始进度: float = 0.0
var 初始位置: Vector2 = Vector2.ZERO
var 平滑曲线: Curve2D
var 残影计时: float = 0.0
var 彩虹相位: float = 0.0


func _validate_property(property: Dictionary) -> void:
	if not 启用非线性:
		if property.name == "路径缓动" or property.name == "中心点停顿":
			property.usage = PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY


func _ready() -> void:
	初始位置 = position
	构建平滑曲线()


func 构建平滑曲线() -> void:
	平滑曲线 = Curve2D.new()
	var d = 半径 * 圆滑度
	var c = d * 0.7

	平滑曲线.add_point(Vector2(-半径, -半径), Vector2(c, c), Vector2(-d, 0))
	平滑曲线.add_point(Vector2(-半径, 半径), Vector2(-d, 0), Vector2(c, -c))
	平滑曲线.add_point(Vector2(半径, -半径), Vector2(-c, c), Vector2(d, 0))
	平滑曲线.add_point(Vector2(半径, 半径), Vector2(d, 0), Vector2(-c, -c))
	平滑曲线.add_point(Vector2(-半径, -半径), Vector2(c, c), Vector2(-d, 0))

	平滑曲线.bake_interval = 1.0


func _process(delta: float) -> void:
	原始进度 = fmod(原始进度 + 循环速度 * delta, 1.0)

	var 当前进度: float = 原始进度

	if 启用非线性:
		if 中心点停顿:
			var t := 原始进度
			if t < 0.375:
				当前进度 = 0.375 * _平滑缓动(t / 0.375, 路径缓动)
			elif t < 0.5:
				当前进度 = 0.375 + 0.125 * _平滑缓动((t - 0.375) / 0.125, 路径缓动)
			elif t < 0.875:
				当前进度 = 0.5 + 0.375 * _平滑缓动((t - 0.5) / 0.375, 路径缓动)
			else:
				当前进度 = 0.875 + 0.125 * _平滑缓动((t - 0.875) / 0.125, 路径缓动)
		else:
			当前进度 = _平滑缓动(原始进度, 路径缓动)
	else:
		当前进度 = 原始进度

	var 曲线总长 = 平滑曲线.get_baked_length()
	var 偏移位置 = 平滑曲线.sample_baked(当前进度 * 曲线总长)
	position = 初始位置 + 偏移位置

	# 残影生成计时
	if 启用残影 and 残影间隔 > 0.0:
		残影计时 += delta
		if 残影计时 >= 残影间隔:
			残影计时 -= 残影间隔
			生成残影()


func 生成残影() -> void:
	if texture == null:
		return

	var 幽灵 := Sprite2D.new()
	幽灵.texture = texture
	幽灵.global_position = global_position
	幽灵.global_rotation = global_rotation
	幽灵.scale = scale
	幽灵.z_index = z_index - 1   # 保证残影在角色身后

	# 每个残影切换一个彩虹色相
	彩虹相位 = fmod(彩虹相位 + 彩虹变化速度 * 0.1, 1.0)
	var 颜色 := Color.from_hsv(彩虹相位, 彩虹饱和度, 1.0)
	幽灵.modulate = Color(颜色.r, 颜色.g, 颜色.b, 残影初始不透明度)

	get_parent().add_child(幽灵)

	# 用 Tween 让它淡出 + 缩小 + 消失
	var tween := 幽灵.create_tween()
	tween.set_parallel(true)
	tween.tween_property(幽灵, "modulate:a", 0.0, 残影存活时间)
	tween.tween_property(幽灵, "scale", scale * 残影缩小比例, 残影存活时间)
	tween.chain().tween_callback(幽灵.queue_free)


func _平滑缓动(x: float, 强度: float) -> float:
	var smooth := x * x * (3.0 - 2.0 * x)
	if 强度 != 1.0:
		smooth = pow(smooth, 强度)
	return smooth
