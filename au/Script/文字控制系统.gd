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
# 这个变量就是你要求的“保存用户选择难度的变量”
var selected_difficulty: String = "NORMAL"
# 默认难度常量（根据你的要求：普通）
const DEFAULT_DIFFICULTY = "NORMAL"
const DEFAULT_DIFFICULTY_INDEX = 2 # NORMAL 在数组中的索引
# =================================================

# ================= 音效设置 =================
@export var ui_sfx: AudioStream  # 唯一音效文件
var sfx_player: AudioStreamPlayer
# ===========================================

func _ready():
	bbcode_enabled = true
	
	# ================= 字体修改 =================
	var my_font = load("res://fonts/MonsterFriendFore.otf") 
	add_theme_font_override("normal_font", my_font)
	add_theme_font_size_override("normal_font_size", 30)
	# ===========================================
	
	# 创建音频播放器
	sfx_player = AudioStreamPlayer.new()
	add_child(sfx_player)
	
	# 游戏开始时，确保游标和已保存的难度同步
	current_difficulty_index = DEFAULT_DIFFICULTY_INDEX
	selected_difficulty = DEFAULT_DIFFICULTY
	
	update_ui()

# 统一的 UI 刷新函数
func update_ui():
	if current_state == State.MAIN_MENU:
		if is_play_selected:
			text = "[color=yellow]pLaY[/color]\ndifficulty"
		else:
			text = "pLaY\n[color=yellow]difficulty[/color]"
			
	elif current_state == State.SELECTING_DIFFICULTY:
		# 获取当前游标选中的难度
		var current_difficulty = difficulty_options[current_difficulty_index]
		
		# 获取当前难度对应的颜色
		var current_color = difficulty_colors[current_difficulty_index]
		
		# 难度选项放在 difficulty 的右侧，并使用对应的颜色标签
		var base_text = "pLaY\n[color=yellow]difficulty[/color]   [color=" + current_color + "]" + current_difficulty + "[/color]"
		
		text = base_text

# 播放音效的辅助函数
func play_sfx():
	if ui_sfx and sfx_player:
		sfx_player.stream = ui_sfx
		sfx_player.play()

func _unhandled_input(event):
	# ---------------- 主菜单状态 ----------------
	if current_state == State.MAIN_MENU:
		# 上键 (静音)
		if event.is_action_pressed("up"):
			play_sfx()
			if not is_play_selected:
				is_play_selected = true
				update_ui()
			get_viewport().set_input_as_handled()
			
		# 下键 (静音)
		elif event.is_action_pressed("down"):
			play_sfx()
			if is_play_selected:
				is_play_selected = false
				update_ui()
			get_viewport().set_input_as_handled()
			
		# 确定键 (Z / Enter) -> 播放音效
		elif event.is_action_pressed("confirm"):
			play_sfx()
			
			if is_play_selected:
				# 选中 pLaY，跳转场景 (记得取消注释并替换路径！)
				# get_tree().change_scene_to_file("res://你的游戏场景.tscn")
				print("跳转游戏场景" ,"\n[" , Time.get_datetime_string_from_system() ,  "]")
			else:
				# 选中 difficulty，进入难度选择阶段
				current_state = State.SELECTING_DIFFICULTY
				# 进入时，游标定位到当前【已保存】的难度上
				current_difficulty_index = difficulty_options.find(selected_difficulty)
				if current_difficulty_index == -1: current_difficulty_index = DEFAULT_DIFFICULTY_INDEX
				update_ui()
			get_viewport().set_input_as_handled()

	# ---------------- 难度选择状态 ----------------
	elif current_state == State.SELECTING_DIFFICULTY:
		# 左键 -> 播放音效
		if event.is_action_pressed("left"): 
			if current_difficulty_index > 0:
				current_difficulty_index -= 1
				play_sfx()
				update_ui()
			get_viewport().set_input_as_handled()
			
		# 右键 -> 播放音效
		elif event.is_action_pressed("right"):
			if current_difficulty_index < difficulty_options.size() - 1:
				current_difficulty_index += 1
				play_sfx()
				update_ui()
			get_viewport().set_input_as_handled()
			
		# 确定键 (Z / Enter) -> 播放音效，并保存选择
		elif event.is_action_pressed("confirm"):
			play_sfx()
			
			# 将用户最终确定的难度保存到变量中
			selected_difficulty = difficulty_options[current_difficulty_index]
			print("确认难度 难度：", selected_difficulty ,"\n[" , Time.get_datetime_string_from_system() ,  "]")
			
			# 回到主菜单
			current_state = State.MAIN_MENU
			update_ui()
			get_viewport().set_input_as_handled()
			
		# 取消键 (X 键) -> 播放音效，撤销本次修改
		elif event.is_action_pressed("cancel"):
			play_sfx()
			
			# 【核心修改】：不修改 selected_difficulty 变量，保留用户之前确认的难度
			# 只需要把游标恢复成之前保存的难度即可
			current_difficulty_index = difficulty_options.find(selected_difficulty)
			if current_difficulty_index == -1: current_difficulty_index = DEFAULT_DIFFICULTY_INDEX
			
			print("取消难度选择 难度：", selected_difficulty ,"\n[" , Time.get_datetime_string_from_system() ,  "]")
			
			# 回到主菜单
			current_state = State.MAIN_MENU
			update_ui()
			get_viewport().set_input_as_handled()
