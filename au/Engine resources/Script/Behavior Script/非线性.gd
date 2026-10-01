extends AnimatedSprite2D

@export var 半径: float = 100.0
@export var 循环速度: float = 0.4
var 执行剧情中: bool = false
var 停止循环移动: bool = false  # 剧情开始后，彻底冻结 ∞ 路径

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
@export var 残影间隔: float = 0.04
@export var 残影存活时间: float = 0.6
@export_range(0.0, 1.0, 0.05) var 残影初始不透明度: float = 0.7
@export_range(0.3, 1.0, 0.05) var 残影缩小比例: float = 0.85
@export var 彩虹变化速度: float = 0.667
@export_range(0.0, 1.0, 0.05) var 彩虹饱和度: float = 0.9

# 🔥 增强：残影数量上限（防止低帧率或疯狂按键时瞬间爆内存）
@export var 残影数量上限: int = 30

@export_group("剧情设置")
@export var 下一场景路径: String = "res://Engine resources/autoload/遭遇动画.tscn"

signal 移动完成
signal 剧情完成

var 正在移动: bool = false
var 原始进度: float = 0.0
var 初始位置: Vector2 = Vector2.ZERO
var 平滑曲线: Curve2D
var 缓存曲线总长: float = 0.0
var 残影计时: float = 0.0
var 彩虹相位: float = 0.0


func _validate_property(property: Dictionary) -> void:
	if not 启用非线性:
		if property.name == "路径缓动" or property.name == "中心点停顿":
			property.usage = PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY


func _ready() -> void:
	初始位置 = position
	构建平滑曲线()
	if sprite_frames and not is_playing():
		play()


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
	缓存曲线总长 = 平滑曲线.get_baked_length()


func _process(delta: float) -> void:
	# 移动过程中也照常执行 ∞ 路径位移计算
	if not 正在移动 and not 停止循环移动:
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

		var 偏移位置 = 平滑曲线.sample_baked(当前进度 * 缓存曲线总长)
		position = 初始位置 + 偏移位置

	# 🟢 看你意图：移动时是否生成残影 —— 这里保留，所以没有加 if not 正在移动 的判断
	if 启用残影 and 残影间隔 > 0.0:
		残影计时 += delta
		while 残影计时 >= 残影间隔:
			残影计时 -= 残影间隔
			生成残影()


# ================= 对外接口：平滑移动 → 执行剧情 =================
func 平滑移动到目标(目标位置: Vector2, 时长: float = 1.0) -> void:
	if 正在移动:
		push_warning("Asriel: 角色正在移动中，忽略本次移动请求")
		return
	正在移动 = true

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "global_position", 目标位置, 时长)
	await tween.finished

	正在移动 = false
	初始位置 = global_position
	原始进度 = 0.0
	
	停止循环移动 = true  # 🔥 核心：立刻停止 ∞ 轨迹，角色定在原地
	
	移动完成.emit()
	await 执行剧情()


# ================= 剧情执行 =================
# ================= 剧情执行 =================
# ================= 剧情执行 =================
func 执行剧情() -> void:
	执行剧情中 = true
	
	# 播放摇头动画
	play("摇头")
	
	# 等“摇头”动画彻底播完
	await animation_finished
	
	# 配置字典必须放在函数内部（或者定义成类成员变量）
	var 完整配置 = {
		# --- 打字机核心 ---
		"打字间隔": 0.05,        # 每个字间隔（秒），越小越快
		
		# --- 字体与颜色 ---
		"字体路径": "res://Material/fonts/FZXS_ 14_fixed.ttf", 
		"字体大小": 30,          
		"默认颜色": Color(1.0, 1.0, 1.0, 0.627), 
		"自定义颜色字符串": "", 
		
		# --- 音效 ---
		"音效路径": "res://Material/sounds/snd_txtasr2.wav", 
		"音效音量": 1.0,         
		
		# --- 位置与首字符 ---
		"X": 320.0,                  
		"Y": 360,                  
		"首字符": "*",
		"首字符静音": true,
		"启用按键推进": true,
	}
	
	打字机.开始打印("你还不明白吗你这个杀人犯", 完整配置)
	await 打字机.请求下一条  # 停住等玩家按 Z 或 X
	
	打字机.开始打印("一遍遍的杀戮一遍遍的屠杀", 完整配置)
	await 打字机.请求下一条
	
	打字机.开始打印("我已经厌倦了", 完整配置)
	await 打字机.请求下一条
	
	打字机.开始打印("可是你还是一遍遍地杀戮着我的同伴", 完整配置)
	await 打字机.请求下一条
	
	打字机.开始打印("一次次的无能为力", 完整配置)
	await 打字机.请求下一条
	
	打字机.开始打印("所以", 完整配置)
	await 打字机.请求下一条
	打字机.开始打印("审判开始!", {"打字间隔": 0.05,"字体路径": "res://Material/fonts/FZXS_ 14_fixed.ttf", "字体大小": 30,"默认颜色": Color(1.0, 0.0, 0.0, 1.0),"音效路径": "res://Material/sounds/snd_txtasr2.wav","音效音量": 1.0,"X": 320.0,"Y": 360,"首字符": "*","首字符静音": true,"启用按键推进": true})
	await 打字机.请求下一条
	打字机.清空内容()
	
	# 剧情结束，先发信号
	剧情完成.emit()
	
	# 🔥 如果需要切换场景，取消下面这两行的注释
	# if 下一场景路径 != "":
	# 	get_tree().change_scene_to_file(下一场景路径)
	
	# 剧情播放完毕，如果不想切场景，角色会一直停在原地摇头结束的那一帧
	执行剧情中 = false
	
	# 5. 【核心修复】别注释了，执行切场景！
	if 下一场景路径 != "":
		get_tree().change_scene_to_file(下一场景路径)
	
	# 6. 解锁（不过因为切了场景这个节点马上销毁了，这行其实执行不到，但为了逻辑完整保留）
	执行剧情中 = false


# 🔥 可选：合并为一行式，顺带解决漏帧
func 等待按键(动作名: String) -> void:
	while not Input.is_action_just_pressed(动作名):
		await get_tree().process_frame


# ================= 残影生成 =================
func 生成残影() -> void:
	if sprite_frames == null:
		return
		
	# 🔥 增强：检查残影数量上限
	if get_tree().get_nodes_in_group("残影").size() >= 残影数量上限:
		return

	var 当前纹理 = sprite_frames.get_frame_texture(animation, frame)
	if 当前纹理 == null:
		return

	var 幽灵 := Sprite2D.new()
	幽灵.texture = 当前纹理
	幽灵.global_position = global_position
	幽灵.global_rotation = global_rotation
	幽灵.scale = scale
	幽灵.z_index = z_index - 1
	
	# 可选：继承翻转状态
	幽灵.flip_h = flip_h
	幽灵.flip_v = flip_v
	
	# 加入组，便于统计数量
	幽灵.add_to_group("残影")

	彩虹相位 = fmod(彩虹相位 + 彩虹变化速度 * 0.1, 1.0)
	var 颜色 := Color.from_hsv(彩虹相位, 彩虹饱和度, 1.0)
	幽灵.modulate = Color(颜色.r, 颜色.g, 颜色.b, 残影初始不透明度)

	# 🔥 可选：get_parent() 空检查
	var 父节点 = get_parent()
	if 父节点:
		父节点.add_child(幽灵)
	else:
		push_warning("Asriel: 没有父节点，残影生成失败")
		return

	var tween := 幽灵.create_tween()
	tween.set_parallel(true)
	tween.tween_property(幽灵, "modulate:a", 0.0, 残影存活时间)
	tween.tween_property(幽灵, "scale", scale * 残影缩小比例, 残影存活时间)
	
	# 🔥 建议改：tween 回调加 is_instance_valid
	tween.finished.connect(func():
		if is_instance_valid(幽灵):
			幽灵.queue_free()
	)


func _平滑缓动(x: float, 强度: float) -> float:
	# 🔥 建议改：加 clamp，防止因浮点数精度问题导致角色闪现
	x = clampf(x, 0.0, 1.0)
	var smooth := x * x * (3.0 - 2.0 * x)
	if 强度 != 1.0:
		smooth = pow(smooth, 强度)
	return smooth
