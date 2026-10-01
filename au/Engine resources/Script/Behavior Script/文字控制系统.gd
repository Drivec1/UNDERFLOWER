extends RichTextLabel

enum State { MAIN_MENU, SELECTING_DIFFICULTY }
var current_state = State.MAIN_MENU

var is_play_selected = true
var current_difficulty_index = 2
var difficulty_options = ["PEACE", "EASY", "NORMAL", "HARD", "EXPERT", "MASTER"]

var difficulty_colors = [
	"#00CC00",
	"#4169E1",
	"#00CED1",
	"#FF8C00",
	"#8B008B",
	"#FFD700",
]

var selected_difficulty: String = "NORMAL"
const DEFAULT_DIFFICULTY = "NORMAL"
const DEFAULT_DIFFICULTY_INDEX = 2

@export var ui_sfx: AudioStream
var sfx_player: AudioStreamPlayer

# ================= 绑定角色 =================
@export var 循环角色: AnimatedSprite2D
@export var 角色目标位置: Vector2 = Vector2(500, 300)
# ============================================


func _ready():
	bbcode_enabled = true

	var my_font = load("res://Material/fonts/MonsterFriendFore.otf")
	add_theme_font_override("normal_font", my_font)
	add_theme_font_size_override("normal_font_size", 30)

	sfx_player = AudioStreamPlayer.new()
	add_child(sfx_player)

	current_difficulty_index = 全局变量.当前难度
	if current_difficulty_index < 0 or current_difficulty_index >= difficulty_options.size():
		current_difficulty_index = DEFAULT_DIFFICULTY_INDEX
	selected_difficulty = difficulty_options[current_difficulty_index]

	update_ui()


func update_ui():
	if current_state == State.MAIN_MENU:
		if is_play_selected:
			text = "[color=yellow]pLaY[/color]\ndifficulty"
		else:
			text = "pLaY\n[color=yellow]difficulty[/color]"
	elif current_state == State.SELECTING_DIFFICULTY:
		var current_difficulty = difficulty_options[current_difficulty_index]
		var current_color = difficulty_colors[current_difficulty_index]
		text = "pLaY\n[color=yellow]difficulty[/color]   [color=" + current_color + "]" + current_difficulty + "[/color]"


func play_sfx():
	if ui_sfx and sfx_player:
		sfx_player.stream = ui_sfx
		sfx_player.play()


func _unhandled_input(event):
	# 如果角色正在移动，或者【正在播放剧情】，直接无视所有输入
	if 循环角色 and (循环角色.正在移动 or 循环角色.执行剧情中):
		return
	
	# ... 剩下的菜单逻辑保持原样 ...
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
				if 循环角色:
					循环角色.平滑移动到目标(角色目标位置, 1.0)
				else:
					get_tree().change_scene_to_file("res://Engine resources/autoload/遭遇动画.tscn")
			else:
				current_state = State.SELECTING_DIFFICULTY
				current_difficulty_index = 全局变量.当前难度
				if current_difficulty_index < 0 or current_difficulty_index >= difficulty_options.size():
					current_difficulty_index = DEFAULT_DIFFICULTY_INDEX
				update_ui()
				get_viewport().set_input_as_handled()

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
			selected_difficulty = difficulty_options[current_difficulty_index]
			全局变量.当前难度 = current_difficulty_index
			print("确认难度 难度：", selected_difficulty, "\n[", Time.get_datetime_string_from_system(), "]")
			current_state = State.MAIN_MENU
			update_ui()
			get_viewport().set_input_as_handled()

		elif event.is_action_pressed("cancel"):
			play_sfx()
			current_difficulty_index = 全局变量.当前难度
			if current_difficulty_index < 0 or current_difficulty_index >= difficulty_options.size():
				current_difficulty_index = DEFAULT_DIFFICULTY_INDEX
			print("取消难度选择 难度：", selected_difficulty, "\n[", Time.get_datetime_string_from_system(), "]")
			current_state = State.MAIN_MENU
			update_ui()
			get_viewport().set_input_as_handled()
