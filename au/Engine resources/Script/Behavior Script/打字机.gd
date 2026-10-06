extends RichTextLabel

# ==================== 默认设置（在检查器里调） ====================
@export_group("打字机核心设置")
@export var 打字间隔: float = 0.05 

@export_group("字体与颜色设置")
@export var 字体路径: String = "res://fonts/MonsterFriendFore.otf"
@export var 字体大小: int = 16
@export var 默认颜色: Color = Color.WHITE
@export var 自定义颜色字符串: String = ""

@export_group("音效设置")
@export var 音效路径: String = "res://sounds/snd_wngdng7.wav"
@export var 音效音量: float = 1.0

# ==================== 首字符设置 ====================
@export_group("首字符设置")
@export var 首字符: String = ""
@export var 首字符静音: bool = true

# ==================== 按键推进设置 ====================
@export_group("按键推进设置")
@export var 启用按键推进: bool = false
@export var 下一个动作名: StringName = &"confirm"
@export var 跳过动作名: StringName = &"cancel"

# ==================== 文字背景框设置 ====================
@export_group("文字背景框设置")
@export var 启用文字背景框: bool = true
@export var 背景框颜色: Color = Color.GREEN
@export var 背景框外扩: float = 0.0

# ---- 外框 ----
@export var 启用外框: bool = true
@export var 外框颜色: Color = Color.WHITE
@export var 外框宽度: float = 6.0

# ==================== 运行时变量 ====================
var 待打印内容: String = ""
var 完整内容: String = ""
var 当前打印数量: int = 0
var 当前行数: int = 0
var _计时器: float = 0.0
var _正在打印: bool = false
var _音效播放器: AudioStreamPlayer
var _解析后的颜色列表: Array[Color] = []
var _纯文本长度: int = 0
var _首字符长度: int = 0

var _背景框: ColorRect = null
var _外框: ColorRect = null
var _测量标签: RichTextLabel = null
var _上次测量数量: int = -1

signal 打字完成
signal 请求下一条

func _ready():
	z_index = 4096
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	bbcode_enabled = true
	scroll_active = true
	scroll_following = true
	get_v_scroll_bar().visible = false
	
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vertical_alignment = VERTICAL_ALIGNMENT_TOP
	
	if size.x == 0 or size.y == 0:
		size = Vector2(800, 200)
		
	_音效播放器 = AudioStreamPlayer.new()
	add_child(_音效播放器)
	
	_创建测量标签()
	_应用字体设置()
	_应用音效设置()
	_解析颜色字符串()
	# 初始化背景框（复用节点，不用 queue_free 重建）
	_创建背景框.call_deferred()
	
	visible_characters = 0
	当前打印数量 = 0
	当前行数 = 1
	_正在打印 = false
	set_process(false)

func _exit_tree():
	if _背景框 and is_instance_valid(_背景框):
		_背景框.queue_free()
	if _外框 and is_instance_valid(_外框):
		_外框.queue_free()

func _应用字体设置():
	if 字体路径 != "" and ResourceLoader.exists(字体路径):
		var 加载的字体 = load(字体路径)
		if 加载的字体 is Font:
			add_theme_font_override("normal_font", 加载的字体)
			add_theme_font_size_override("normal_font_size", 字体大小)
	add_theme_color_override("default_color", 默认颜色)
	_同步字体设置到测量标签()

func _应用音效设置():
	_音效播放器.volume_db = linear_to_db(音效音量)
	if 音效路径 != "" and ResourceLoader.exists(音效路径):
		var 加载的音效 = load(音效路径)
		if 加载的音效 is AudioStream:
			_音效播放器.stream = 加载的音效

func _解析颜色字符串():
	_解析后的颜色列表.clear()
	if 自定义颜色字符串.strip_edges() == "":
		return
	for 块 in 自定义颜色字符串.split("."):
		var 数值 = 块.split(",")
		if 数值.size() >= 3:
			_解析后的颜色列表.append(Color(float(数值[0])/255.0, float(数值[1])/255.0, float(数值[2])/255.0))

# ==================== 测量标签 ====================
func _创建测量标签():
	if _测量标签 and is_instance_valid(_测量标签):
		return
	_测量标签 = RichTextLabel.new()
	_测量标签.bbcode_enabled = false
	_测量标签.scroll_active = false
	_测量标签.scroll_following = false
	_测量标签.autowrap_mode = TextServer.AUTOWRAP_OFF
	_测量标签.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_测量标签.position = Vector2(-100000, -100000)
	_测量标签.size = Vector2(20000, 20000)
	add_child(_测量标签)
	_同步字体设置到测量标签()

func _同步字体设置到测量标签():
	if not _测量标签 or not is_instance_valid(_测量标签):
		return
	if 字体路径 != "" and ResourceLoader.exists(字体路径):
		var 加载的字体 = load(字体路径)
		if 加载的字体 is Font:
			_测量标签.add_theme_font_override("normal_font", 加载的字体)
			_测量标签.add_theme_font_size_override("normal_font_size", 字体大小)
	_测量标签.add_theme_color_override("default_color", 默认颜色)

func _获取已显示尺寸() -> Vector2:
	if 当前打印数量 <= 0:
		return Vector2.ZERO
	if 当前打印数量 != _上次测量数量:
		_测量标签.text = 完整内容.substr(0, 当前打印数量)
		_上次测量数量 = 当前打印数量
	var w = _测量标签.get_content_width()
	var h = _测量标签.get_content_height()
	return Vector2(w, h)
# ============================================================

# ==================== 外框 + 背景框（复用节点，避免闪现旧框） ====================
func _创建背景框():
	var 父节点 = get_parent()
	if not 父节点:
		return
	
	# ---- 先立即隐藏旧的，避免在重建时闪一下 ----
	if _背景框 and is_instance_valid(_背景框):
		_背景框.visible = false
		_背景框.size = Vector2.ZERO
	if _外框 and is_instance_valid(_外框):
		_外框.visible = false
		_外框.size = Vector2.ZERO
	
	# ---- 外框：已存在就更新属性，不存在才创建 ----
	if 启用文字背景框 and 启用外框:
		if not _外框 or not is_instance_valid(_外框):
			_外框 = ColorRect.new()
			_外框.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_外框.z_index = z_index - 2
			_外框.top_level = true
			_外框.size = Vector2.ZERO
			父节点.add_child.call_deferred(_外框)
		_外框.color = 外框颜色
	else:
		# 关闭外框 → 有则清掉
		if _外框 and is_instance_valid(_外框):
			_外框.queue_free()
		_外框 = null
	
	# ---- 背景框：已存在就更新属性，不存在才创建 ----
	if 启用文字背景框:
		if not _背景框 or not is_instance_valid(_背景框):
			_背景框 = ColorRect.new()
			_背景框.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_背景框.z_index = z_index - 1
			_背景框.top_level = true
			_背景框.size = Vector2.ZERO
			父节点.add_child.call_deferred(_背景框)
		_背景框.color = 背景框颜色
	else:
		if _背景框 and is_instance_valid(_背景框):
			_背景框.queue_free()
		_背景框 = null

## 根据"已显示文字"的尺寸重新计算背景框和外框大小
func _更新背景框():
	if not 启用文字背景框: return
	if not _测量标签 or not is_instance_valid(_测量标签): return
	
	if 当前打印数量 <= 0:
		if _背景框 and is_instance_valid(_背景框):
			_背景框.size = Vector2.ZERO
		if _外框 and is_instance_valid(_外框):
			_外框.size = Vector2.ZERO
		return
	
	var 已显示尺寸 = _获取已显示尺寸()
	var 内容宽 = 已显示尺寸.x
	var 内容高 = 已显示尺寸.y
	if 内容宽 <= 0 or 内容高 <= 0:
		return
	
	if _背景框 and is_instance_valid(_背景框):
		_背景框.global_position = global_position + Vector2(-背景框外扩, -背景框外扩)
		_背景框.size = Vector2(
			内容宽 + 背景框外扩 * 2.0,
			内容高 + 背景框外扩 * 2.0
		)
	
	if _外框 and is_instance_valid(_外框):
		var 外框偏移 = 背景框外扩 + 外框宽度
		_外框.global_position = global_position + Vector2(-外框偏移, -外框偏移)
		_外框.size = Vector2(
			内容宽 + 外框偏移 * 2.0,
			内容高 + 外框偏移 * 2.0
		)
# ============================================================

## 【核心接口】对外公开
func 开始打印(新的内容: String, 动态配置: Dictionary = {}):
	if 动态配置.has("打字间隔"): 打字间隔 = 动态配置["打字间隔"]
	if 动态配置.has("字体路径"): 字体路径 = 动态配置["字体路径"]
	if 动态配置.has("字体大小"): 字体大小 = 动态配置["字体大小"]
	if 动态配置.has("默认颜色"): 默认颜色 = 动态配置["默认颜色"]
	if 动态配置.has("自定义颜色字符串"): 自定义颜色字符串 = 动态配置["自定义颜色字符串"]
	if 动态配置.has("音效路径"): 音效路径 = 动态配置["音效路径"]
	if 动态配置.has("音效音量"): 音效音量 = 动态配置["音效音量"]
	if 动态配置.has("首字符"): 首字符 = 动态配置["首字符"]
	if 动态配置.has("首字符静音"): 首字符静音 = 动态配置["首字符静音"]
	if 动态配置.has("启用按键推进"): 启用按键推进 = 动态配置["启用按键推进"]
	if 动态配置.has("下一个动作名"): 下一个动作名 = 动态配置["下一个动作名"]
	if 动态配置.has("跳过动作名"): 跳过动作名 = 动态配置["跳过动作名"]
	if 动态配置.has("启用文字背景框"): 启用文字背景框 = 动态配置["启用文字背景框"]
	if 动态配置.has("背景框颜色"): 背景框颜色 = 动态配置["背景框颜色"]
	if 动态配置.has("背景框外扩"): 背景框外扩 = 动态配置["背景框外扩"]
	if 动态配置.has("启用外框"): 启用外框 = 动态配置["启用外框"]
	if 动态配置.has("外框颜色"): 外框颜色 = 动态配置["外框颜色"]
	if 动态配置.has("外框宽度"): 外框宽度 = 动态配置["外框宽度"]
	
	_应用字体设置()
	_应用音效设置()
	_解析颜色字符串()
	_创建背景框()
	
	待打印内容 = 新的内容
	_首字符长度 = 首字符.length()
	完整内容 = 首字符 + 待打印内容
	_纯文本长度 = 完整内容.length()
	
	var 构建好的文本 = ""
	var 颜色数量 = _解析后的颜色列表.size()
	
	for i in range(_纯文本长度):
		var 单个字符 = 完整内容[i]
		var 当前颜色 = 默认颜色
		if 颜色数量 > 0:
			当前颜色 = _解析后的颜色列表[i % 颜色数量]
		构建好的文本 += "[color=#%s]%s[/color]" % [当前颜色.to_html(false), 单个字符]
	
	text = 构建好的文本
	
	# 先隐藏所有元素，避免闪现
	visible = false
	if _背景框 and is_instance_valid(_背景框):
		_背景框.visible = false
		_背景框.size = Vector2.ZERO
	if _外框 and is_instance_valid(_外框):
		_外框.visible = false
		_外框.size = Vector2.ZERO
	visible_characters = 0
	
	# 预计算文本尺寸 + 定位
	await get_tree().process_frame
	
	var 内容宽 = get_content_width()
	var 内容高 = get_content_height()
	var 视口尺寸 = get_viewport_rect().size
	
	var 起始x = (视口尺寸.x - 内容宽) / 2.0
	var 起始y = (视口尺寸.y - 内容高) / 2.0
	
	var target_x = 动态配置.get("X", 0)
	var target_y = 动态配置.get("Y", 0)
	if target_x != 0:
		起始x = target_x - 内容宽 / 2.0
	if target_y != 0:
		起始y = target_y - 内容高 / 2.0
	
	offset_left = 起始x
	offset_top = 起始y
	offset_right = 起始x + 内容宽
	offset_bottom = 起始y + 内容高
	
	# 再等一帧，让新位置和背景框初始化完成
	await get_tree().process_frame
	_更新背景框()
	
	# 一切就绪，统一显示
	visible = true
	if _背景框 and is_instance_valid(_背景框):
		_背景框.visible = true
	if _外框 and is_instance_valid(_外框):
		_外框.visible = true
	
	visible_characters = 0
	当前打印数量 = 0
	当前行数 = 1
	_计时器 = 0.0
	_上次测量数量 = -1
	_正在打印 = true
	set_process(true)

func _process(delta):
	if not _正在打印: return
	_计时器 += delta
	if _计时器 >= 打字间隔:
		_计时器 -= 打字间隔 
		visible_characters += 1
		当前打印数量 = visible_characters
		当前行数 = get_line_count()
		
		var 允许播放音效 = true
		if 首字符静音 and 当前打印数量 <= _首字符长度:
			允许播放音效 = false
		
		if 允许播放音效 and _音效播放器 and _音效播放器.stream != null:
			_音效播放器.play()
		
		_更新背景框()
		
		if 当前打印数量 >= _纯文本长度:
			_正在打印 = false
			set_process(false)
			_更新背景框()
			emit_signal("打字完成")

# ==================== 清空 ====================
func 清空内容():
	_正在打印 = false
	set_process(false)
	text = ""
	visible_characters = 0
	当前打印数量 = 0
	当前行数 = 1
	待打印内容 = ""
	完整内容 = ""
	_纯文本长度 = 0
	_首字符长度 = 0
	_计时器 = 0.0
	_上次测量数量 = -1
	if _音效播放器 and _音效播放器.playing:
		_音效播放器.stop()
	if _背景框 and is_instance_valid(_背景框):
		_背景框.size = Vector2.ZERO
	if _外框 and is_instance_valid(_外框):
		_外框.size = Vector2.ZERO
# ==========================================================

# ==================== 按键推进 ====================
func _unhandled_input(event):
	if not 启用按键推进:
		return
	if not event.is_pressed():
		return
	
	if event.is_action_pressed(跳过动作名):
		if _正在打印:
			_立即完成打印()
		get_viewport().set_input_as_handled()
		return
	
	if event.is_action_pressed(下一个动作名):
		if not _正在打印:
			emit_signal("请求下一条")
		get_viewport().set_input_as_handled()
		return

func _立即完成打印():
	_正在打印 = false
	set_process(false)
	visible_characters = _纯文本长度
	当前打印数量 = _纯文本长度
	当前行数 = get_line_count()
	if _音效播放器 and _音效播放器.playing:
		_音效播放器.stop()
	_更新背景框()
	emit_signal("打字完成")
	print("打字机：按键跳过打字动画，直接显示全部文字。")
# ======================================================
