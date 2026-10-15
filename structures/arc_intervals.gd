class_name ArcIntervals
extends RefCounted
## Boundary distances are doubles; never store intervals in float32 Vector2.
const EPS:=0.00001
static func wrapped(start: float,width: float,total: float) -> Array:
	if width>=total-EPS:return [[0.0,total]]
	var lo=fposmod(start,total);var hi=lo+width
	return [[lo,hi]] if hi<=total else [[0.0,hi-total],[lo,total]]
static func merge(ranges: Array) -> Array:
	var sorted=ranges.duplicate(true)
	sorted.sort_custom(func(a,b):return a[0]<b[0])
	var result: Array=[]
	for span in sorted:
		if span[1]-span[0]<=EPS:continue
		if not result.is_empty() and span[0]<=result[-1][1]+EPS:result[-1][1]=maxf(result[-1][1],span[1])
		else:result.append(span.duplicate())
	return result
static func subtract(ranges: Array,cuts: Array) -> Array:
	var result=ranges.duplicate(true)
	for cut in cuts:
		var remaining: Array=[]
		for span in result:
			if cut[1]<=span[0] or cut[0]>=span[1]:remaining.append(span);continue
			if cut[0]>span[0]+EPS:remaining.append([span[0],cut[0]])
			if cut[1]<span[1]-EPS:remaining.append([cut[1],span[1]])
		result=remaining
	return result
static func overlap(a: Array,b: Array) -> float:
	var result=0.0
	for x in a:
		for y in b:result+=maxf(0,minf(x[1],y[1])-maxf(x[0],y[0]))
	return result
