extends Sprite2D

# 在检查器里设定你希望角色在屏幕上显示的高度（像素）
@export var 期望高度: float = 100.0

func _ready():
	if texture:
		# 获取贴图原始尺寸（比如你那张 1600x600）
		var 贴图原始高度 = texture.get_height()
		
		# 避免除以零
		if 贴图原始高度 > 0:
			# 自动计算缩放比例
			var 比例 = 期望高度 / 贴图原始高度
			
			# 关键：X 和 Y 设为同一个值，绝对防变形！
			scale = Vector2(比例, 比例)
