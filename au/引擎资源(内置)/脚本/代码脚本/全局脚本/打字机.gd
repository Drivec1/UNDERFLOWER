extends Node
## ==========================================================
##  打字机 —— Autoload 单例版
##  项目 → 项目设置 → 全局 → 自动加载：
##      路径选本脚本，节点名填「打字机」
## ==========================================================

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
var _准备中: bool = false   # 🔥 关键：打字机还在定位/构建文本时，不响应按键
var _音效播放器: AudioStreamPlayer
var _解析后的颜色列表: Array[Color] = []
var _纯文本长度: int = 0
var _首字符长度: int = 0

var _画布层: CanvasLayer
var _文本标签: RichTextLabel
var _背景框: ColorRect = null
var _外框: ColorRect = null
var _测量标签: RichTextLabel = null
var _上次测量数量: int = -1

signal 打字完成
signal 请求下一条

func _ready():
	# 1. 画布层
	_画布层 = CanvasLayer.new()
	_画布层.layer = 100
	add_child(_画布层)
	
	# 2. RichTextLabel
	_文本标签 = RichTextLabel.new()
	_文本标签.z_index = 4096
	_文本标签.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_文本标签.bbcode_enabled = true
	_文本标签.scroll_active = true
	_文本标签.scroll_following = true
	_文本标签.get_v_scroll_bar().visible = false
	
	# 🔥 关键修复：关闭自动换行，防止每个字符单独占一行
	_文本标签.autowrap_mode = TextServer.AUTOWRAP_OFF
	
	_文本标签.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_文本标签.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_文本标签.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_文本标签.size = Vector2(2000, 200)
	_文本标签.visible = false
	
	_画布层.add_child(_文本标签)
	
	# 3. 音效播放器
	_音效播放器 = AudioStreamPlayer.new()
	add_child(_音效播放器)
	
	_创建测量标签()
	_应用字体设置()
	_应用音效设置()
	_解析颜色字符串()
	_创建背景框.call_deferred()

func _exit_tree():
	if _背景框 and is_instance_valid(_背景框):
		_背景框.queue_free()
	if _外框 and is_instance_valid(_外框):
		_外框.queue_free()

func _应用字体设置():
	if 字体路径 != "" and ResourceLoader.exists(字体路径):
		var 加载的字体 = load(字体路径)
		if 加载的字体 is Font:
			_文本标签.add_theme_font_override("normal_font", 加载的字体)
			_文本标签.add_theme_font_size_override("normal_font_size", 字体大小)
	_文本标签.add_theme_color_override("default_color", 默认颜色)
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
	_画布层.add_child(_测量标签)
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

# ==================== 外框 + 背景框 ====================
func _创建背景框():
	var 父节点 = _画布层
	if not 父节点:
		return
	
	if _背景框 and is_instance_valid(_背景框):
		_背景框.visible = false
		_背景框.size = Vector2.ZERO
	if _外框 and is_instance_valid(_外框):
		_外框.visible = false
		_外框.size = Vector2.ZERO
	
	if 启用文字背景框 and 启用外框:
		if not _外框 or not is_instance_valid(_外框):
			_外框 = ColorRect.new()
			_外框.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_外框.z_index = 4094
			_外框.top_level = true
			_外框.size = Vector2.ZERO
			父节点.add_child.call_deferred(_外框)
		_外框.color = 外框颜色
	else:
		if _外框 and is_instance_valid(_外框):
			_外框.queue_free()
		_外框 = null
	
	if 启用文字背景框:
		if not _背景框 or not is_instance_valid(_背景框):
			_背景框 = ColorRect.new()
			_背景框.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_背景框.z_index = 4095
			_背景框.top_level = true
			_背景框.size = Vector2.ZERO
			父节点.add_child.call_deferred(_背景框)
		_背景框.color = 背景框颜色
	else:
		if _背景框 and is_instance_valid(_背景框):
			_背景框.queue_free()
		_背景框 = null

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
		_背景框.global_position = _文本标签.global_position + Vector2(-背景框外扩, -背景框外扩)
		_背景框.size = Vector2(
			内容宽 + 背景框外扩 * 2.0,
			内容高 + 背景框外扩 * 2.0
		)
	
	if _外框 and is_instance_valid(_外框):
		var 外框偏移 = 背景框外扩 + 外框宽度
		_外框.global_position = _文本标签.global_position + Vector2(-外框偏移, -外框偏移)
		_外框.size = Vector2(
			内容宽 + 外框偏移 * 2.0,
			内容高 + 外框偏移 * 2.0
		)
# ============================================================

## 【核心接口】对外公开
func 开始打印(新的内容: String, 动态配置: Dictionary = {}):
	# 🔥 进入准备阶段：立刻屏蔽按键，防止跳句
	_准备中 = true
	_正在打印 = false
	set_process(false)
	
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
	
	# 🔥 清掉可能混进来的 \r \n，防止出现莫名换行
	新的内容 = 新的内容.replace("\r", "").replace("\n", "")
	
	待打印内容 = 新的内容
	_首字符长度 = 首字符.length()
	完整内容 = 首字符 + 待打印内容
	_纯文本长度 = 完整内容.length()
	
	# 🔥 构建文本：
	#    - 单色（无自定义颜色）：直接用纯文本，避免逐字 bbcode 触发换行
	#    - 多色：用 push_color / add_text / pop，不生成 bbcode 标签
	var 颜色数量 = _解析后的颜色列表.size()
	_文本标签.clear()
	if 颜色数量 == 0:
		_文本标签.text = 完整内容
	else:
		for i in range(_纯文本长度):
			var 单个字符 = 完整内容[i]
			var 当前颜色 = _解析后的颜色列表[i % 颜色数量]
			_文本标签.push_color(当前颜色)
			_文本标签.add_text(单个字符)
			_文本标签.pop()
	
	_文本标签.visible = false
	if _背景框 and is_instance_valid(_背景框):
		_背景框.visible = false
		_背景框.size = Vector2.ZERO
	if _外框 and is_instance_valid(_外框):
		_外框.visible = false
		_外框.size = Vector2.ZERO
	_文本标签.visible_characters = 0
	
	await get_tree().process_frame
	
	var 内容宽 = _文本标签.get_content_width()
	var 内容高 = _文本标签.get_content_height()
	var 视口尺寸 = _文本标签.get_viewport_rect().size
	
	var 起始x = (视口尺寸.x - 内容宽) / 2.0
	var 起始y = (视口尺寸.y - 内容高) / 2.0
	
	var target_x = 动态配置.get("X", 0)
	var target_y = 动态配置.get("Y", 0)
	if target_x != 0:
		起始x = target_x - 内容宽 / 2.0
	if target_y != 0:
		起始y = target_y - 内容高 / 2.0
	
	_文本标签.offset_left = 起始x
	_文本标签.offset_top = 起始y
	_文本标签.offset_right = 起始x + 内容宽 + 4.0   # 留一点余量防止贴边换行
	_文本标签.offset_bottom = 起始y + 内容高
	
	await get_tree().process_frame
	_更新背景框()
	
	_文本标签.visible = true
	if _背景框 and is_instance_valid(_背景框):
		_背景框.visible = true
	if _外框 and is_instance_valid(_外框):
		_外框.visible = true
	
	_文本标签.visible_characters = 0
	当前打印数量 = 0
	当前行数 = 1
	_计时器 = 0.0
	_上次测量数量 = -1
	
	# 🔥 真正开始打印：解除准备中，进入打印中
	_正在打印 = true
	_准备中 = false
	set_process(true)

func _process(delta):
	if not _正在打印: return
	_计时器 += delta
	if _计时器 >= 打字间隔:
		_计时器 -= 打字间隔 
		_文本标签.visible_characters += 1
		当前打印数量 = _文本标签.visible_characters
		当前行数 = _文本标签.get_line_count()
		
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
	_准备中 = false
	set_process(false)
	_文本标签.text = ""
	_文本标签.visible_characters = 0
	_文本标签.visible = false
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
		_背景框.visible = false
	if _外框 and is_instance_valid(_外框):
		_外框.size = Vector2.ZERO
		_外框.visible = false
# ==========================================================

# ==================== 按键推进 ====================
func _unhandled_input(event):
	if not 启用按键推进:
		return
	if not event.is_pressed():
		return
	
	# 🔥 准备中直接忽略，防止打字机还没定位好就被推进
	if _准备中:
		return
	
	if event.is_action_pressed(跳过动作名):
		if _正在打印:
			_立即完成打印()
		get_viewport().set_input_as_handled()
		return
	
	if event.is_action_pressed(下一个动作名):
		if _正在打印:
			_立即完成打印()      # 打字中按回车 → 先瞬间显示完整
		else:
			emit_signal("请求下一条")  # 打完了再按回车 → 进入下一句
		get_viewport().set_input_as_handled()
		return

func _立即完成打印():
	_正在打印 = false
	set_process(false)
	_文本标签.visible_characters = _纯文本长度
	当前打印数量 = _纯文本长度
	当前行数 = _文本标签.get_line_count()
	if _音效播放器 and _音效播放器.playing:
		_音效播放器.stop()
	_更新背景框()
	emit_signal("打字完成")
# ======================================================
