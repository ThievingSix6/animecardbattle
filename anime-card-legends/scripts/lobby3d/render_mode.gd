class_name RenderMode
extends RefCounted

# =========================================================
# What the renderer can actually take.
#
# This project runs on the GL Compatibility renderer, which draws in
# LDR: any lighting or emission that totals above 1.0 clips to flat
# white with no bloom to make it read as brightness. The neon values
# that look right on Forward+ (emission 3.0, lights at 2-3 energy)
# come out as white silhouettes here.
#
# So every light and emission strength in the 3D worlds is routed
# through these, and the same scene stays legible on either renderer.
# =========================================================

const LDR_LIGHT_CEILING := 1.15
const LDR_EMISSION_CEILING := 1.0

static var _checked := false
static var _high_dynamic_range := false


# Forward+ and Mobile both render in HDR and support glow.
# Compatibility does not, and is the only one with no RenderingDevice.
static func is_hdr() -> bool:
	if not _checked:
		_checked = true
		_high_dynamic_range = RenderingServer.get_rendering_device() != null
	return _high_dynamic_range


static func supports_glow() -> bool:
	return is_hdr()


# A light energy that will not clip. Pass the value you would use on
# Forward+ and it is scaled down on Compatibility rather than clamped,
# so the relative brightness of two lights survives.
static func light(energy: float) -> float:
	if is_hdr():
		return energy
	return minf(energy, LDR_LIGHT_CEILING)


static func emission(energy: float) -> float:
	if is_hdr():
		return energy
	return minf(energy, LDR_EMISSION_CEILING)
