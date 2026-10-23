extends Node
## ============================================================
##  网页请求 —— 放进「自动加载」当单例用
##
##  ------------------------------------------------------------
##  调用格式（一个字典，必须是字典）
##  ------------------------------------------------------------
##
##      网页请求.发送({
##          "url":  "http://192.168.1.5:8080/加血/100",
##          "方式": "GET",
##          "接收": "当前血量",
##      })
##
##  ------------------------------------------------------------
##  三个字段
##  ------------------------------------------------------------
##
##   url  ← 路径
##          写成：http:// + IP + : + 端口 + / + 你要传的信息
##          例：http://192.168.1.5:8080/加血/100
##          所有信息都放在路径里，不用另写数据
##          路径里的中文会自动转成 %XX（不转的话服务器会返回 400）
##          别名：网址、链接、address
##
##   方式 → 请求方式
##          "GET" / "POST" / "PUT" / "DELETE" / "HEAD" / "PATCH"
##          不写就是 GET
##          别名：方法、method
##
##   请求体 → 可选。要发给服务器的内容，**默认按 JSON 处理**
##          写字典或数组 → 自动 JSON.stringify，
##                         并自动补 Content-Type: application/json
##          写字符串     → 原样发出去，但也默认按 JSON 声明类型
##          带了请求体时，方式一般要写 POST 或 PUT
##          别名：请求体JSON、数据、body、参数、内容
##
##   接收 ← 结果放到哪个变量
##          直接写「全局变量」单例里的变量名，不要写路径、不要加点
##          例："当前血量"
##          别名：存到、变量、结果变量、接收变量、target
##
##  ------------------------------------------------------------
##  结果去哪了
##  ------------------------------------------------------------
##    1) 写进 全局变量.接收的那个名字        ← 主用途
##       如果局域网同步开着，这个值还会自动同步给其他玩家
##    2) 同时在 网页请求.结果["那个名字"] 留一份
##    3) 发 完成 / 失败 两个信号
##
##  返回值是这次请求的编号（int），参数不合法返回 -1。
## ============================================================


# ============================================================
#  可以改的开关
# ============================================================

## 结果写进哪个节点。你的变量都在「全局变量」里，所以默认就是它。
var 接收节点: String = "/root/全局变量"

## 请求超时（秒）
var 超时秒数: int = 10

## 结果缓存：网页请求.结果["当前血量"]
var 结果: Dictionary = {}


# ============================================================
#  信号
# ============================================================

signal 完成(编号: int, 变量名: String, 值: Variant)
signal 失败(编号: int, 变量名: String, 原因: String)


var _编号: int = 0


# ============================================================
#  主接口
# ============================================================

func 发送(参数) -> int:
	if typeof(参数) != TYPE_DICTIONARY:
		push_error("网页请求：参数必须是字典（Dictionary），收到的是 " + 类型名(参数))
		return -1

	var 字典: Dictionary = 参数

	# ---------- url（路径） ----------
	var 网址 := str(_取字段(字典, ["url", "网址", "链接", "address"], "")).strip_edges()
	if 网址.is_empty():
		push_error("网页请求：字典里没填 url")
		return -1
	if not (网址.begins_with("http://") or 网址.begins_with("https://")):
		push_error("网页请求：url 要写成 http://IP:端口/路径，现在是：" + 网址)
		return -1
	网址 = _编码网址(网址)

	# ---------- 方式（不写默认 GET） ----------
	var 方式 := str(_取字段(字典, ["方式", "方法", "method"], "GET")).strip_edges().to_upper()
	var 方法: int = HTTPClient.METHOD_GET
	match 方式:
		"GET", "":  方法 = HTTPClient.METHOD_GET
		"POST":     方法 = HTTPClient.METHOD_POST
		"PUT":      方法 = HTTPClient.METHOD_PUT
		"PATCH":    方法 = HTTPClient.METHOD_PATCH
		"DELETE":   方法 = HTTPClient.METHOD_DELETE
		"HEAD":     方法 = HTTPClient.METHOD_HEAD
		_:
			push_error("网页请求：不认识的方式「" + 方式 + "」，支持 GET/POST/PUT/PATCH/DELETE/HEAD")
			return -1

	# ---------- 接收（全局变量里的变量名） ----------
	var 变量名 := str(_取字段(字典, ["接收", "存到", "变量", "结果变量", "接收变量", "target"], "")).strip_edges()
	if 变量名.is_empty():
		push_error("网页请求：字典里没写「接收」，不知道该把结果放到哪个变量")
		return -1

	# ---------- 可选：请求体 / 头 / 类型 ----------
	var 数据 = _取字段(字典, ["请求体", "请求体JSON", "数据", "body", "参数", "内容"], null)
	var 头 = _取字段(字典, ["头", "headers", "请求头"], {})
	var 类型 := str(_取字段(字典, ["类型", "convert"], "自动")).strip_edges()

	var 头数组 := PackedStringArray()
	if typeof(头) == TYPE_DICTIONARY:
		for 键 in 头:
			头数组.append(str(键) + ": " + str(头[键]))

	# ---------- 请求体：默认就是 JSON ----------
	var 有内容类型 := false
	for 一行 in 头数组:
		if 一行.to_lower().begins_with("content-type"):
			有内容类型 = true
			break

	var 正文 := ""
	if 数据 != null:
		if typeof(数据) == TYPE_STRING:
			正文 = 数据                       # 你自己拼好的字符串，原样发
		else:
			正文 = JSON.stringify(数据)        # 字典 / 数组 / 数字 → JSON
		if not 有内容类型:
			头数组.append("Content-Type: application/json; charset=utf-8")
		if 方法 == HTTPClient.METHOD_GET:
			push_warning("网页请求：带了请求体但方式是 GET，服务器多半会忽略它。要用 POST 就把 \"方式\" 写成 \"POST\"")

	# ---------- 发 ----------
	var 请求 := HTTPRequest.new()
	请求.timeout = 超时秒数
	请求.accept_gzip = true
	add_child(请求)

	_编号 += 1
	var 本次编号 := _编号

	请求.request_completed.connect(_收到响应.bind(本次编号, 变量名, 类型, 请求))

	var 错误 := 请求.request(网址, 头数组, 方法, 正文)
	if 错误 != OK:
		请求.queue_free()
		var 原因 := "请求发不出去：" + error_string(错误)
		失败.emit(本次编号, 变量名, 原因)
		push_error("网页请求：" + 原因)
		return -1

	return 本次编号


## GET 快捷方法
func 取(网址: String, 接收: String, 类型: String = "自动") -> int:
	return 发送({"url": 网址, "方式": "GET", "接收": 接收, "类型": 类型})


## POST 一个 JSON 请求体（最常用）
func 提交JSON(网址: String, 请求体, 接收: String, 类型: String = "自动") -> int:
	return 发送({"url": 网址, "方式": "POST", "请求体": 请求体, "接收": 接收, "类型": 类型})


## POST JSON 快捷方法（旧名字，一样能用）
func 提交(网址: String, 数据, 接收: String, 类型: String = "自动") -> int:
	return 发送({"url": 网址, "方式": "POST", "请求体": 数据, "接收": 接收, "类型": 类型})


## 取缓存里的结果
func 取结果(变量名: String) -> Variant:
	return 结果.get(变量名, null)


# ============================================================
#  内部
# ============================================================

func _取字段(字典: Dictionary, 候选名: Array, 默认值):
	for 名 in 候选名:
		if 字典.has(名):
			return 字典[名]
	return 默认值


## 把网址里 :// 后面的非 ASCII / 不安全字符转成 %XX。
## 中文路径（例如 http://ip:8080/加血/100）不做这一步的话，
## 服务器会返回 400 Bad Request，请求根本发不出去。
func _编码网址(网址: String) -> String:
	var 井号 := 网址.find("#")
	var 干净 := 网址 if 井号 < 0 else 网址.substr(0, 井号)

	var 分界 := 干净.find("://")
	if 分界 < 0:
		return 干净

	var 前缀 := 干净.substr(0, 分界 + 3)      # http:// 或 https://
	var 其余 := 干净.substr(分界 + 3)          # 主机 + 路径 + 查询串

	# 原样保留的字符；% 保留是为了不把已经编码好的再编一遍
	var 保留 := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~/:?&=%,+@!$'()*;[]"

	var 新网址 := ""
	for 字节 in 其余.to_utf8_buffer():
		var 单字 := char(字节)
		if 字节 < 128 and 保留.contains(单字):
			新网址 += 单字
		else:
			新网址 += "%%%02X" % 字节
	return 前缀 + 新网址


func _收到响应(结果码: int, 状态码: int, _响应头: PackedStringArray, 正文: PackedByteArray,
		本次编号: int, 变量名: String, 类型: String, 请求: HTTPRequest) -> void:

	if is_instance_valid(请求):
		请求.queue_free()

	if 结果码 != HTTPRequest.RESULT_SUCCESS:
		var 原因 := "请求失败：" + _结果码说明(结果码)
		失败.emit(本次编号, 变量名, 原因)
		push_warning("网页请求 -> " + 变量名 + " " + 原因)
		return

	if 状态码 < 200 or 状态码 >= 300:
		var 原因2 := "服务器返回了状态码 " + str(状态码)
		失败.emit(本次编号, 变量名, 原因2)
		push_warning("网页请求 -> " + 变量名 + " " + 原因2)
		return

	var 文本 := 正文.get_string_from_utf8()
	var 值: Variant = _转换(文本, 类型, 变量名)

	结果[变量名] = 值
	_写进节点(变量名, 值)
	完成.emit(本次编号, 变量名, 值)


func _转换(文本: String, 类型: String, 变量名: String) -> Variant:
	var 干净 := 文本.strip_edges()
	match 类型:
		"字符串", "文本", "string":
			return 文本
		"整数", "int":
			return int(干净)
		"浮点", "小数", "float":
			return float(干净)
		"布尔", "bool":
			return _转布尔(干净)
		"JSON", "json":
			var 解析 = JSON.parse_string(文本)
			return 解析 if 解析 != null else 文本

	# ---- 自动：按目标变量原本的类型来 ----
	var 原值 = _读节点(变量名)
	match typeof(原值):
		TYPE_INT:
			return int(干净)
		TYPE_FLOAT:
			return float(干净)
		TYPE_BOOL:
			return _转布尔(干净)
		TYPE_DICTIONARY, TYPE_ARRAY, TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_VECTOR3:
			var 解析2 = JSON.parse_string(文本)
			if 解析2 != null:
				return 解析2

	var 解析3 = JSON.parse_string(文本)
	if 解析3 != null and (typeof(解析3) == TYPE_DICTIONARY or typeof(解析3) == TYPE_ARRAY):
		return 解析3
	return 文本


func _转布尔(文本: String) -> bool:
	return 文本.to_lower() in ["true", "1", "yes", "on", "是", "真", "成功"]


func _读节点(变量名: String) -> Variant:
	var 目标 := get_node_or_null(接收节点)
	if 目标 == null:
		return null
	return 目标.get(变量名)


func _写进节点(变量名: String, 值: Variant) -> void:
	var 目标 := get_node_or_null(接收节点)
	if 目标 == null:
		push_warning("网页请求：找不到节点 " + 接收节点 + "，结果只存在了 网页请求.结果 里")
		return

	for 属性 in 目标.get_property_list():
		if 属性.name == 变量名:
			目标.set(变量名, 值)
			return

	push_warning("网页请求：" + 接收节点 + " 上没有名为「" + 变量名 + "」的变量，没写进去（结果仍在 网页请求.结果 里）")


func _结果码说明(码: int) -> String:
	match 码:
		HTTPRequest.RESULT_SUCCESS: return "成功"
		HTTPRequest.RESULT_CHUNKED_BODY_SIZE_MISMATCH: return "分块长度对不上"
		HTTPRequest.RESULT_CANT_CONNECT: return "连不上（网址写错 / 服务器没开 / 被防火墙拦了）"
		HTTPRequest.RESULT_CANT_RESOLVE: return "域名解析不了"
		HTTPRequest.RESULT_CONNECTION_ERROR: return "连接过程中出错"
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR: return "HTTPS 握手失败（证书问题）"
		HTTPRequest.RESULT_NO_RESPONSE: return "服务器没有回应"
		HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED: return "响应内容太大"
		HTTPRequest.RESULT_BODY_DECOMPRESS_FAILED: return "响应解压失败"
		HTTPRequest.RESULT_REQUEST_FAILED: return "请求失败"
		HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN: return "存文件打不开"
		HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR: return "写文件出错"
		HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED: return "跳转次数太多"
		HTTPRequest.RESULT_TIMEOUT: return "超时（服务器太慢了）"
		_: return "未知错误 " + str(码)


func 类型名(值) -> String:
	match typeof(值):
		TYPE_NIL: return "null"
		TYPE_BOOL: return "布尔"
		TYPE_INT: return "整数"
		TYPE_FLOAT: return "浮点"
		TYPE_STRING: return "字符串"
		TYPE_ARRAY: return "数组"
		TYPE_DICTIONARY: return "字典"
		_: return type_string(typeof(值))
