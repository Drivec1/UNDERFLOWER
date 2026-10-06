extends Node
## ==========================================================
##  舞台 —— Autoload 单例（纯简化 API 版）
##  项目 → 项目设置 → 全局 → 自动加载：
##      路径选本脚本，节点名填「舞台」
## ==========================================================

## true = 固定在屏幕上；false = 跟随相机
var 屏幕坐标: bool = true

## 默认层级（所有简化 API 都作用在这个层级）
## 如果你想用更高层（比如覆盖在 UI 上面），直接改这里，例如：舞台.默认层级 = "10"
var 默认层级: String = "0"

# 内部管理表
var _层级表: Dictionary = {}    # 层级名 -> CanvasLayer
var _节点表: Dictionary = {}    # 层级名 -> AnimatedSprite2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


# ==========================================================
#  简化 API（只有下面这几个方法，全部不需要写层级！）
# ==========================================================

## 1. 播放图片
## 用法：舞台.播放图片("res://Material/a.png")
##      舞台.播放图片("res://Material/a.png", "100", "200")
func 播放图片(图片路径: String, x := "0", y := "0") -> void:
	_刷新显示(图片路径, "", x, y)


## 2. 播放动画
## 用法：舞台.播放动画("res://Material/a.res")
##      舞台.播放动画("res://Material/a.res", "摇头")
##      舞台.播放动画("res://Material/a.res", "摇头", "100", "200")
func 播放动画(动画路径: String, 动画名 := "", x := "0", y := "0") -> void:
	_刷新显示("", 动画路径, x, y, 动画名)


## 3. 停止（隐藏当前内容，下次调用播放图片/动画会自动覆盖）
func 停止() -> void:
	if _节点表.has(默认层级):
		(_节点表[默认层级] as AnimatedSprite2D).stop()
		(_节点表[默认层级] as AnimatedSprite2D).visible = false
	if _层级表.has(默认层级):
		(_层级表[默认层级] as CanvasLayer).visible = false


## 4. 显示（把上次隐藏的内容重新显示出来）
func 显示() -> void:
	if _节点表.has(默认层级):
		(_节点表[默认层级] as AnimatedSprite2D).visible = true
	if _层级表.has(默认层级):
		(_层级表[默认层级] as CanvasLayer).visible = true


## 5. 移动（把当前显示的图片/动画挪到新位置）
## 用法：舞台.移动("100", "200")
func 移动(x := "0", y := "0") -> void:
	if _节点表.has(默认层级):
		(_节点表[默认层级] as AnimatedSprite2D).position = Vector2(_转数字(x), _转数字(y))


## 6. 播放音效
## 用法：舞台.播放音效("res://sounds/click.wav")
##      舞台.播放音效("res://sounds/click.wav", 0.5)  # 50% 音量
func 播放音效(音效路径: String, 音量 := 1.0) -> void:
	if 音效路径 == "":
		return
	var 流 = load(音效路径)
	if not (流 is AudioStream):
		push_warning("舞台：音效加载失败或格式不支持 → %s" % 音效路径)
		return

	var 播放器 := AudioStreamPlayer.new()
	播放器.stream = 流
	播放器.volume_db = linear_to_db(clampf(音量, 0.0, 1.0))
	播放器.bus = "Master"
	add_child(播放器)

	# 播完自动销毁，不占内存
	播放器.finished.connect(播放器.queue_free)
	播放器.play()


## 7. 全部清除（连层级节点一起删掉，适合切换场景前调用）
func 全部清除() -> void:
	for 层 in _层级表.values():
		(层 as CanvasLayer).queue_free()
	_层级表.clear()
	_节点表.clear()


# ==========================================================
#  内部实现（不用管，改坏了会报错）
# ==========================================================

## 内部统一的显示刷新逻辑
func _刷新显示(图片路径: String, 动画路径: String, x, y, 指定动画名 := "") -> void:
	var 名 := 默认层级
	var 层 := _取层级(名)
	var 节点 := _取节点(名)

	节点.position = Vector2(_转数字(x), _转数字(y))

	var 帧资源 := _构建帧(图片路径, 动画路径)
	if 帧资源 == null:
		push_warning("舞台：没有可用的贴图 / 动画")
		return

	节点.sprite_frames = 帧资源
	节点.visible = true

	# 自动选择要播放的动画
	var 名列表 := 帧资源.get_animation_names()
	var 要播的动画 := ""
	if 指定动画名 != "" and 帧资源.has_animation(指定动画名):
		要播的动画 = 指定动画名
	elif 帧资源.has_animation("default"):
		要播的动画 = "default"
	elif 名列表.size() > 0:
		要播的动画 = 名列表[0]

	if 要播的动画 != "":
		节点.play(要播的动画)
	else:
		push_warning("舞台：资源里没有任何动画帧")

	层.visible = true


## 构建 SpriteFrames（支持单张 png 和 .res）
func _构建帧(图片路径: String, 动画路径: String) -> SpriteFrames:
	if 动画路径 != "":
		var 资源 = load(动画路径)
		if 资源 is SpriteFrames:
			return 资源
		push_warning("舞台：动画资源不是 SpriteFrames → %s" % 动画路径)

	if 图片路径 != "":
		var tex = load(图片路径)
		if tex is Texture2D:
			var sf := SpriteFrames.new()
			sf.add_frame("default", tex)
			sf.set_animation_speed("default", 1.0)
			sf.set_animation_loop("default", false)
			return sf
		push_warning("舞台：图片加载失败 → %s" % 图片路径)

	return null


func _取层级(名: String) -> CanvasLayer:
	if _层级表.has(名):
		return _层级表[名]
	var 层 := CanvasLayer.new()
	层.name = "舞台层级_" + 名
	层.layer = 名.to_int() if 名.is_valid_int() else 0
	层.follow_viewport_enabled = not 屏幕坐标
	add_child(层)
	_层级表[名] = 层
	return 层


func _取节点(名: String) -> AnimatedSprite2D:
	if _节点表.has(名):
		return _节点表[名]
	var 节点 := AnimatedSprite2D.new()
	节点.name = "动画_" + 名
	节点.visible = false
	_取层级(名).add_child(节点)
	_节点表[名] = 节点
	return 节点


func _转数字(s) -> float:
	var t := str(s)
	return t.to_float() if t.is_valid_float() else 0.0
