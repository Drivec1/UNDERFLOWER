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
## 留空 = 不添加；填了字符 = 会先于正文打印出来
@export var 首字符: String = ""
## 首字符打印期间是否静音（默认静音）
@export var 首字符静音: bool = true

# ==================== 按键推进设置 ====================
@export_group("按键推进设置")
## 是否启用按键推进
@export var 启用按键推进: bool = false
## "下一个"的输入动作名（默认对应 Z 键 / confirm）
@export var 下一个动作名: StringName = &"confirm"
## "跳过"的输入动作名（默认对应 X 键 / cancel）
@export var 跳过动作名: StringName = &"cancel"

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
	
	_应用字体设置()
	_应用音效设置()
	_解析颜色字符串()
	
	visible_characters = 0
	当前打印数量 = 0
	当前行数 = 1
	_正在打印 = false
	set_process(false)

func _应用字体设置():
	if 字体路径 != "" and ResourceLoader.exists(字体路径):
		var 加载的字体 = load(字体路径)
		if 加载的字体 is Font:
			add_theme_font_override("normal_font", 加载的字体)
			add_theme_font_size_override("normal_font_size", 字体大小)
	add_theme_color_override("default_color", 默认颜色)

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

## 【核心接口】对外公开
func 开始打印(新的内容: String, 动态配置: Dictionary = {}):
	# 覆盖默认值
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
	
	_应用字体设置()
	_应用音效设置()
	_解析颜色字符串()
	
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
	
	# ==================== 预计算文本尺寸 + 定位 ====================
	visible_characters = -1
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
	# ==========================================================
	
	visible_characters = 0
	当前打印数量 = 0
	当前行数 = 1
	_计时器 = 0.0
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
		
		if 当前打印数量 >= _纯文本长度:
			_正在打印 = false
			set_process(false)
			emit_signal("打字完成")

# ==================== 清空当前展示的内容 ====================
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
	if _音效播放器 and _音效播放器.playing:
		_音效播放器.stop()
# ==========================================================

# ==================== 按键推进逻辑 ====================
func _unhandled_input(event):
	if not 启用按键推进:
		return
	if not event.is_pressed():
		return
	
	# ---- 处理"跳过"键（X / cancel）----
	if event.is_action_pressed(跳过动作名):
		if _正在打印:
			# 打字中按 X：瞬间显示全部文字（停留），不触发下一句
			_立即完成打印()
		# else: 打字已完成，X 键什么都不干
		get_viewport().set_input_as_handled()
		return
	
	# ---- 处理"下一个"键（Z / confirm）----
	if event.is_action_pressed(下一个动作名):
		if not _正在打印:
			# 已经打完按 Z：进入下一句
			emit_signal("请求下一条")
		# else: 打字中按 Z 键，什么都不干
		get_viewport().set_input_as_handled()
		return

## 立即显示全部文字并结束打字
func _立即完成打印():
	_正在打印 = false
	set_process(false)
	visible_characters = _纯文本长度
	当前打印数量 = _纯文本长度
	当前行数 = get_line_count()
	if _音效播放器 and _音效播放器.playing:
		_音效播放器.stop()
	emit_signal("打字完成")
	print("打字机：按键跳过打字动画，直接显示全部文字。")
# ======================================================
