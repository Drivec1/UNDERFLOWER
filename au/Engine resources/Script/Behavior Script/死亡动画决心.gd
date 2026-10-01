extends Sprite2D

# ================== 暴露给资源器（Inspector）的变量 ==================

@export_group("移动参数")
@export var 目标位置: Vector2 = Vector2(360, 640)
@export_range(0.1, 10.0, 0.1) var 移动时间: float = 1.0
@export_range(0.0, 10.0, 0.1) var 移动后等待时间: float = 0.5

@export_group("抖动参数")
@export_range(0.1, 10.0, 0.1) var 抖动持续时间: float = 3.0
@export var 抖动幅度: float = 8.0
@export_range(0.01, 0.5, 0.01) var 抖动频率: float = 0.05

@export_group("碎裂与消失参数")
@export var 碎裂贴图: Texture2D
@export_range(0.1, 5.0, 0.1) var 碎裂后停顿时间: float = 0.5
@export var 碎片贴图数组: Array[Texture2D] = []

@export_group("碎片弹起参数")
@export var 碎片弹起水平范围: Vector2 = Vector2(-60, 60) 
@export var 碎片弹起垂直范围: Vector2 = Vector2(-80, -40)
@export_range(0.05, 2.0, 0.05) var 碎片弹起时间: float = 0.25

@export_group("碎片下落参数")
@export var 碎片下落终点Y: float = 1000.0 
# 【提示】建议把这里的负值改掉，保持纯正数，否则可能会触发超时保护
@export var 碎片下落垂直随机: Vector2 = Vector2(0, 30) 
@export var 碎片下落水平范围: Vector2 = Vector2(50, 150) 
@export_range(0.1, 5.0, 0.1) var 碎片下落时间: float = 0.8

@export_group("碎片变身参数")
@export_range(0.01, 0.5, 0.01) var 变换间隔: float = 0.05
@export var 变换总次数: int = 8
@export var 碎片旋转速度: float = 360.0

@export_group("后续动画")
@export var 后续动画名称: String = "渐变线路"

# ====================================================================

@onready var 动画控制器: AnimationPlayer = $"../../动画控制器"

func _ready():
	# 1. 传送
	global_position = 全局变量.决心
	
	# 2. 缓入缓出移动到目标位置
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "global_position", 目标位置, 移动时间)
	await tween.finished
	
	# 3. 等待
	await get_tree().create_timer(移动后等待时间).timeout
	
	# 4. 抖动
	await 执行抖动()
	
	# 5. 变成碎裂贴图
	if 碎裂贴图:
		texture = 碎裂贴图
	else:
		push_warning("没有在资源器里设置【碎裂贴图】！")
	
	global_position = 目标位置
	
	# 6. 停顿后消失
	await get_tree().create_timer(碎裂后停顿时间).timeout
	visible = false
	
	# 7. 生成碎片，并等待【所有碎片】全部达到终点 Y
	await 生成碎片分身(目标位置)
	
	# 8. 所有碎片消失后，播放动画控制器的动画
	if 动画控制器:
		动画控制器.play("渐变线路")
		await get_tree().create_timer(1.8).timeout
		var 完整配置 = {
			# --- 打字机核心 ---
			"打字间隔": 0.5,        # 每个字间隔（秒），越小越快
			
			# --- 字体与颜色 ---
			"字体路径": "res://Material/fonts/FZXS_12-Pixel.ttf", # 填你项目里的字体路径
			"字体大小": 30,          # 字号
			"默认颜色": Color(1.0, 0.0, 0.0, 0.627), # 默认颜色（白色）
			
			# --- 音效 ---
			"音效路径": "res://Material/sounds/snd_txtasr2.wav", # 填你项目里的音效路径
			"音效音量": 1.0,         # 0.0 到 1.0
			
			# --- 位置 ---
			# 如果不填X和Y，或者都填0，会自动在屏幕正中间显示
			"X": 85,                  # 距离屏幕左边的像素
			"Y": 270,                 # 距离屏幕顶部的像素
			"首字符": "*",
			"首字符静音": true,
		}
		
		# 调用全局单例
		打字机.开始打印("给我滚进地狱里焚烧!!!", 完整配置)
	else:
		push_warning("没有找到【动画控制器】节点，请检查场景树路径！")


func 执行抖动():
	var 基准坐标 = global_position
	var 已用时间 = 0.0
	while 已用时间 < 抖动持续时间:
		global_position = 基准坐标 + Vector2(randf_range(-抖动幅度, 抖动幅度), randf_range(-抖动幅度, 抖动幅度))
		await get_tree().create_timer(抖动频率).timeout
		已用时间 += 抖动频率
	global_position = 基准坐标


# 生成碎片
func 生成碎片分身(位置: Vector2):
	if 碎片贴图数组.is_empty():
		push_warning("没有在资源器里设置【碎片贴图数组】！")
		return

	var 所有碎片节点: Array[Sprite2D] = []
	
	# 提前分配最终材质（允许重复，但绝不能全同）
	var 最终材质列表: Array[Texture2D] = []
	for i in range(4):
		var 随机图片 = 碎片贴图数组[randi() % 碎片贴图数组.size()]
		最终材质列表.append(随机图片)
	
	if 最终材质列表[0] == 最终材质列表[1] and 最终材质列表[1] == 最终材质列表[2] and 最终材质列表[2] == 最终材质列表[3]:
		var 不同图片 = 碎片贴图数组[randi() % 碎片贴图数组.size()]
		while 不同图片 == 最终材质列表[0]:
			不同图片 = 碎片贴图数组[randi() % 碎片贴图数组.size()]
		最终材质列表[3] = 不同图片

	for i in range(4):
		var 碎片 = Sprite2D.new()
		碎片.texture = 碎片贴图数组[randi() % 碎片贴图数组.size()]
		
		var 随机偏移 = Vector2(randf_range(-15, 15), randf_range(-15, 15))
		碎片.global_position = 位置 + 随机偏移
		碎片.rotation = randf_range(-PI, PI)
		
		get_parent().add_child(碎片)
		所有碎片节点.append(碎片)
		
		执行材质闪烁(碎片, 最终材质列表[i])
		执行碎片运动(碎片)
	
	# 等待所有碎片到底
	await 等待全部碎片到底(所有碎片节点)


# 【修改】逐帧检测：直到所有碎片的 Y 都大于等于“碎片下落终点Y”后，才继续往下执行
func 等待全部碎片到底(碎片列表: Array[Sprite2D]):
	var 等待超时 = 0.0
	
	while true:
		var 全部到底 = true
		
		for 碎片 in 碎片列表:
			# 已被销毁的碎片算作已经到底
			if not is_instance_valid(碎片):
				continue
			
			# 只要还有任何一个碎片的 Y 小于“碎片下落终点Y”，就说明它还没落到位
			if 碎片.global_position.y < 碎片下落终点Y:
				全部到底 = false
				break
		
		if 全部到底:
			break
		
		# 等待下一帧再检查
		await get_tree().process_frame
		等待超时 += get_process_delta_time()
		
		# 【超时保护】防止因为垂直随机数为负导致永远无法满足条件而死循环
		if 等待超时 > 3.0:
			push_warning("等待碎片到底超时！请检查“碎片下落垂直随机”是否包含负数。")
			break
	
	# 【关键】循环退出后，强制销毁所有剩下的碎片，避免它们留在屏幕上
	for 碎片 in 碎片列表:
		if is_instance_valid(碎片):
			碎片.queue_free()


# 独立协程1：负责材质闪烁与锁定
func 执行材质闪烁(碎片: Sprite2D, 最终材质: Texture2D):
	var 当前变换次数 = 0
	while 当前变换次数 < 变换总次数:
		await get_tree().create_timer(变换间隔).timeout
		if is_instance_valid(碎片):
			碎片.texture = 碎片贴图数组[randi() % 碎片贴图数组.size()]
			当前变换次数 += 1
	
	if is_instance_valid(碎片):
		碎片.texture = 最终材质


# 独立协程2：负责弹起与下落
func 执行碎片运动(碎片: Sprite2D):
	var 起点 = 碎片.global_position
	
	# ========== 弹起阶段 ==========
	var 弹起水平偏移 = randf_range(碎片弹起水平范围.x, 碎片弹起水平范围.y)
	var 弹起垂直偏移 = randf_range(碎片弹起垂直范围.x, 碎片弹起垂直范围.y)
	var 最高点 = 起点 + Vector2(弹起水平偏移, 弹起垂直偏移)
	
	var 弹起Tween = 碎片.create_tween()
	弹起Tween.tween_property(碎片, "global_position", 最高点, 碎片弹起时间)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	await 弹起Tween.finished
	if not is_instance_valid(碎片):
		return
	
	# ========== 下落阶段 ==========
	var 向外方向 = sign(弹起水平偏移)
	if 向外方向 == 0:
		向外方向 = 1 if randf() > 0.5 else -1
	
	var 本次水平距离 = randf_range(abs(碎片下落水平范围.x), abs(碎片下落水平范围.y))
	var 本次水平终点偏移 = 向外方向 * 本次水平距离
	
	var 下落垂直随机 = randf_range(碎片下落垂直随机.x, 碎片下落垂直随机.y)
	
	var 落点X = 最高点.x + 本次水平终点偏移
	var 落点Y = 碎片下落终点Y + 下落垂直随机
	
	# 水平方向：EASE_OUT —— 从快到慢
	var 水平Tween = 碎片.create_tween()
	水平Tween.tween_property(碎片, "global_position:x", 落点X, 碎片下落时间)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# 垂直方向：加速下落（重力）
	var 垂直Tween = 碎片.create_tween()
	垂直Tween.tween_property(碎片, "global_position:y", 落点Y, 碎片下落时间)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# 旋转
	if 碎片旋转速度 != 0:
		var 总时间 = 碎片弹起时间 + 碎片下落时间
		var 旋转目标 = 碎片.rotation + deg_to_rad(碎片旋转速度 * 总时间) * randf_range(-1, 1)
		var 旋转Tween = 碎片.create_tween()
		旋转Tween.tween_property(碎片, "rotation", 旋转目标, 总时间)
	
	# 【关键修复】等下落 Tween 跑完（也就是碎片下落时间），立即销毁碎片，不再等 5 秒
	await get_tree().create_timer(碎片下落时间).timeout
	if is_instance_valid(碎片):
		碎片.queue_free()
