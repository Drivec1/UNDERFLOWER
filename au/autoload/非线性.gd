extends Sprite2D

@export var 半径: float = 100.0        # ∞ 形大小
@export var 循环速度: float = 0.4      # 每秒走完整圈的百分比

@export_group("非线性设置")
@export var 启用非线性: bool = true:
	set(value):
		启用非线性 = value
		notify_property_list_changed()

@export_range(0.1, 5.0, 0.1) var 路径缓动: float = 1.0  # 非线性强度：1.0 为完美平滑
@export var 中心点停顿: bool = true    # 是否在交叉点(0,0)处速度归零

@export_group("曲线平滑度")
@export_range(0.1, 1.0, 0.05) var 圆滑度: float = 0.4  # 越大转弯越圆滑，但形状略偏离标准∞

var 原始进度: float = 0.0
var 初始位置: Vector2 = Vector2.ZERO
var 平滑曲线: Curve2D


func _validate_property(property: Dictionary) -> void:
	if not 启用非线性:
		if property.name == "路径缓动" or property.name == "中心点停顿":
			property.usage = PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY


func _ready() -> void:
	初始位置 = position
	构建平滑曲线()


# 构建平滑的 ∞ 曲线：顶点处控制点方向取圆和斜线的折中，避免多余的 S 形
func 构建平滑曲线() -> void:
	平滑曲线 = Curve2D.new()
	var d = 半径 * 圆滑度       # 沿圆方向的控制点长度
	var c = d * 0.7              # 沿斜线方向的控制点分量（45°）

	# 左上 P0：入从右下斜线来，出去左下圆
	平滑曲线.add_point(Vector2(-半径, -半径), Vector2(c, c), Vector2(-d, 0))
	# 左下 P1：入从左上圆来，出去右上斜线
	平滑曲线.add_point(Vector2(-半径, 半径), Vector2(-d, 0), Vector2(c, -c))
	# 右上 P2：入从左下斜线来，出去右下圆
	平滑曲线.add_point(Vector2(半径, -半径), Vector2(-c, c), Vector2(d, 0))
	# 右下 P3：入从右上圆来，出去左上斜线
	平滑曲线.add_point(Vector2(半径, 半径), Vector2(d, 0), Vector2(-c, -c))
	# 闭合回到左上
	平滑曲线.add_point(Vector2(-半径, -半径), Vector2(c, c), Vector2(-d, 0))

	平滑曲线.bake_interval = 1.0


func _process(delta: float) -> void:
	原始进度 = fmod(原始进度 + 循环速度 * delta, 1.0)

	var 当前进度: float = 原始进度

	if 启用非线性:
		if 中心点停顿:
			# 在 t=0.375 和 t=0.875（中心交叉点）处速度平滑归零
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


func _平滑缓动(x: float, 强度: float) -> float:
	var smooth := x * x * (3.0 - 2.0 * x)
	if 强度 != 1.0:
		smooth = pow(smooth, 强度)
	return smooth
