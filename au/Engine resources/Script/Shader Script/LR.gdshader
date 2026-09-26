shader_type canvas_item;

// ================= 滚动设置 =================
uniform vec2 scroll_speed = vec2(0.1, 0.0); 
uniform bool loop = true; 

// ================= 染色设置 =================
// 默认白色(1,1,1)，不改变原图颜色
uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// ================= 呼吸循环（亮度渐变）设置 =================
// 呼吸速度：数值越大，变色越快
uniform float pulse_speed : hint_range(0.1, 10.0) = 1.5;
// 最低亮度（0代表全黑，1代表贴图原本亮度）
uniform float min_brightness : hint_range(0.0, 1.0) = 0.0;
// 最高亮度
uniform float max_brightness : hint_range(0.0, 2.0) = 1.0;

void fragment() {
	// 1. 滚动逻辑
	vec2 offset = TIME * scroll_speed;
	vec2 final_uv;
	
	if (loop) {
		final_uv = fract(UV + offset);
	} else {
		final_uv = clamp(UV + offset, vec2(0.0), vec2(1.0));
	}
	
	// 2. 读取贴图原本的颜色
	vec4 tex_color = texture(TEXTURE, final_uv);
	
	// 3. 染色（相乘），保留纹理和明暗
	vec4 final_color = tex_color * tint_color;
	
	// 4. 计算“从0到最高再回到0”的循环因子
	// sin() 的输出是 -1 到 1，加上1再乘0.5，就变成了 0 到 1 之间来回摆动
	float pulse = (sin(TIME * pulse_speed) + 1.0) * 0.5;
	
	// 5. 用 pulse 因子在最低亮度和最高亮度之间插值
	float current_brightness = mix(min_brightness, max_brightness, pulse);
	
	// 6. 将亮度应用到最终颜色上
	final_color.rgb *= current_brightness;
	
	// 7. 输出最终颜色（保留透明度）
	COLOR = final_color;
}
