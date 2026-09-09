class_name Fmt
extends RefCounted

# =========================================================
# FORMATTING - shared number/text presentation helpers.
# =========================================================

const UNITS: Array[String] = ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc", "Ud", "Dd"]


# 1234567 -> "1,234,567"
static func commas(n: int) -> String:
	var s := str(abs(n))
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i != 0:
			out = "," + out
	var prefix := ""
	if n < 0:
		prefix = "-"
	return prefix + out


# 1234567 -> "1.23M". For stats that grow exponentially past readability.
static func compact(n: int) -> String:
	var value := float(abs(n))
	var tier := 0
	while value >= 1000.0 and tier < UNITS.size() - 1:
		value /= 1000.0
		tier += 1
	var text := str(int(value))
	if tier > 0:
		text = ("%.2f" % value).trim_suffix("0").trim_suffix("0").trim_suffix(".")
	var prefix := ""
	if n < 0:
		prefix = "-"
	return prefix + text + UNITS[tier]


# 0.000004 -> "1 in 250,000"
static func odds(probability: float) -> String:
	if probability <= 0.0:
		return "—"
	var one_in := 1.0 / probability
	if one_in >= 1000000.0:
		return "1 in " + compact(int(one_in))
	return "1 in " + commas(int(round(one_in)))


# 185.0 -> "3:05"
static func clock(seconds: float) -> String:
	var total := int(max(0.0, seconds))
	var m := int(total / 60.0)
	var s := total % 60
	var secs := str(s)
	if s < 10:
		secs = "0" + secs
	return str(m) + ":" + secs


static func percent(value: float, decimals: int = 0) -> String:
	return String.num(value * 100.0, decimals) + "%"
