extends RichTextLabel

# 定义两个状态
enum State { MAIN_MENU, SELECTING_DIFFICULTY }
var current_state = State.MAIN_MENU

# 主菜单状态：当前是否选中"pLaY" (true) 还是 "difficulty" (false)
var is_play_selected = true

# 难度选择状态：当前游标所在的难度索引 (0 到 5)
var current_difficulty_index = 2 # 默认游标停在 NORMAL (索引2)
var difficulty_options = ["PEACE", "EASY", "NORMAL", "HARD", "EXPERT", "MASTER"]

# ================= 给难度配上对应的颜色 =================
var difficulty_colors = [
	"#00CC00", 
	"#4169E1", 
	"#00CED1", 
	"#FF8C00", 
	"#8B008B", 
	"#FFD700", 
]
# =======================================================

# ================= 保存用户的选择 =================
var selected_difficulty: String = "NORMAL"
const DEFAULT_DIFFICULTY = "NORMAL"
const DEFAULT_DIFFICULTY_INDEX = 2
# =================================================

# ================= 音效设置 =================
@export var ui_sfx: AudioStream
var sfx_player: AudioStreamPlayer
# ===========================================

func _ready():
	bbcode_enabled = true
	
	# ================= 字体修改 =================
	var my_font = load("res://Material/fonts/MonsterFriendFore.otf") 
	add_theme_font_override("normal_font", my_font)
	add_theme_font_size_override("normal_font_size", 30)
	# ===========================================
	
	# 创建音频播放器
	sfx_player = AudioStreamPlayer.new()
	add_child(sfx_player)
	
	# ================= 【核心修改】与全局变量同步 =================
	# 使用你截图里注册的名字 "全局变量"
	current_difficulty_index = 全局变量.当前难度
	
	if current_difficulty_index < 0 or current_difficulty_index >= difficulty_options.size():
		current_difficulty_index = DEFAULT_DIFFICULTY_INDEX
		
	selected_difficulty = difficulty_options[current_difficulty_index]
	# ==============================================================
	
	update_ui()

# 统一的 UI 刷新函数
func update_ui():
	if current_state == State.MAIN_MENU:
		if is_play_selected:
			text = "[color=yellow]pLaY[/color]\ndifficulty"
		else:
			text = "pLaY\n[color=yellow]difficulty[/color]"
			
	elif current_state == State.SELECTING_DIFFICULTY:
		var current_difficulty = difficulty_options[current_difficulty_index]
		var current_color = difficulty_colors[current_difficulty_index]
		var base_text = "pLaY\n[color=yellow]difficulty[/color]   [color=" + current_color + "]" + current_difficulty + "[/color]"
		text = base_text

func play_sfx():
	if ui_sfx and sfx_player:
		sfx_player.stream = ui_sfx
		sfx_player.play()

func _unhandled_input(event):
	# ---------------- 主菜单状态 ----------------
	if current_state == State.MAIN_MENU:
		if event.is_action_pressed("up"):
			if not is_play_selected:
				is_play_selected = true
				play_sfx()
				update_ui()
			get_viewport().set_input_as_handled()
			
		elif event.is_action_pressed("down"):
			if is_play_selected:
				is_play_selected = false
				play_sfx()
				update_ui()
			get_viewport().set_input_as_handled()
			
		elif event.is_action_pressed("confirm"):
			play_sfx()
			
			if is_play_selected:
				get_viewport().set_input_as_handled()
				get_tree().change_scene_to_file("res://Engine resources/autoload/遭遇动画.tscn")
				print("跳转游戏场景" ,"\n[" , Time.get_datetime_string_from_system() ,  "]")
			else:
				current_state = State.SELECTING_DIFFICULTY
				
				# 【核心修改】使用 "全局变量"
				current_difficulty_index = 全局变量.当前难度
				if current_difficulty_index < 0 or current_difficulty_index >= difficulty_options.size():
					current_difficulty_index = DEFAULT_DIFFICULTY_INDEX
					
				update_ui()
				get_viewport().set_input_as_handled()

	# ---------------- 难度选择状态 ----------------
	elif current_state == State.SELECTING_DIFFICULTY:
		if event.is_action_pressed("left"): 
			if current_difficulty_index > 0:
				current_difficulty_index -= 1
				play_sfx()
				update_ui()
			get_viewport().set_input_as_handled()
			
		elif event.is_action_pressed("right"):
			if current_difficulty_index < difficulty_options.size() - 1:
				current_difficulty_index += 1
				play_sfx()
				update_ui()
			get_viewport().set_input_as_handled()
			
		elif event.is_action_pressed("confirm"):
			play_sfx()
			
			# 保存到本地变量
			selected_difficulty = difficulty_options[current_difficulty_index]
			
			# ================= 【核心修改】写入全局变量 =================
			# 使用 "全局变量"
			全局变量.当前难度 = current_difficulty_index
			# ===========================================================
			
			print("确认难度 难度：", selected_difficulty ,"\n[" , Time.get_datetime_string_from_system() ,  "]")
			
			current_state = State.MAIN_MENU
			update_ui()
			get_viewport().set_input_as_handled()
			
		elif event.is_action_pressed("cancel"):
			play_sfx()
			
			# 【核心修改】使用 "全局变量" 恢复
			current_difficulty_index = 全局变量.当前难度
			if current_difficulty_index < 0 or current_difficulty_index >= difficulty_options.size():
				current_difficulty_index = DEFAULT_DIFFICULTY_INDEX
			
			print("取消难度选择 难度：", selected_difficulty ,"\n[" , Time.get_datetime_string_from_system() ,  "]")
			
			current_state = State.MAIN_MENU
			update_ui()
			get_viewport().set_input_as_handled()
