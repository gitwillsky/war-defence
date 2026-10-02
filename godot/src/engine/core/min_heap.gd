class_name MinHeap
extends RefCounted
## 二叉小根堆（优先级 float，值 int），供 Dijkstra 等使用。

var _prios := PackedFloat32Array()
var _vals := PackedInt32Array()


func size() -> int:
	return _vals.size()


func is_empty() -> bool:
	return _vals.is_empty()


func push(prio: float, value: int) -> void:
	_prios.append(prio)
	_vals.append(value)
	var i := _vals.size() - 1
	while i > 0:
		var p := (i - 1) >> 1
		if _prios[p] <= _prios[i]:
			break
		_swap(i, p)
		i = p


## 弹出优先级最小的值。
func pop() -> int:
	var top := _vals[0]
	var last := _vals.size() - 1
	_prios[0] = _prios[last]
	_vals[0] = _vals[last]
	_prios.resize(last)
	_vals.resize(last)
	var i := 0
	while true:
		var l := i * 2 + 1
		var r := l + 1
		var m := i
		if l < last and _prios[l] < _prios[m]:
			m = l
		if r < last and _prios[r] < _prios[m]:
			m = r
		if m == i:
			break
		_swap(i, m)
		i = m
	return top


func _swap(a: int, b: int) -> void:
	var tp := _prios[a]
	_prios[a] = _prios[b]
	_prios[b] = tp
	var tv := _vals[a]
	_vals[a] = _vals[b]
	_vals[b] = tv
