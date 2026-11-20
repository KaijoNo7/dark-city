extends RefCounted
## Gamepad detection and button naming (static helper library).
## Usage:  const PadInfo := preload("res://scripts/input/pad_info.gd")
##
## Godot reads every controller through SDL's "standard gamepad" layout, so
## button 0 is always the bottom face button (Xbox A / PlayStation Cross),
## button 6 is always Start/Options, and so on. What changes between brands
## is only the *name printed on the button*. This file works out which brand
## a controller is (from its name and USB vendor/product IDs) so menus can
## show "Cross" to a PlayStation player and "A" to an Xbox player.

enum Family { GENERIC, XBOX, PS2, PS3, PS4, PS5, SWITCH }

const FAMILY_NAMES := {
	Family.GENERIC: "Generic gamepad",
	Family.XBOX: "Xbox controller",
	Family.PS2: "PlayStation 2 (USB adapter)",
	Family.PS3: "PlayStation 3 (DualShock 3)",
	Family.PS4: "PlayStation 4 (DualShock 4)",
	Family.PS5: "PlayStation 5 (DualSense)",
	Family.SWITCH: "Nintendo Switch controller",
}

# USB vendor / product IDs (the numbers every USB device reports).
const VID_SONY := 0x054C
const VID_MICROSOFT := 0x045E
const PID_PS3 := [0x0268]
const PID_PS4 := [0x05C4, 0x09CC, 0x0BA0]
const PID_PS5 := [0x0CE6, 0x0DF2]
# Common PS1/PS2-to-USB adapter chips ("Twin USB Joystick", "WiseGroup").
const VID_PS2_ADAPTERS := [0x0810, 0x0925]
const PS2_WORDS := ["ps2", "playstation 2", "playstation(r)2", "playstation®2", "twin usb",
	"dual usb", "psx", "wisegroup", "ps1/ps2", "ps/ps2"]

# Button names in SDL order: 0 bottom, 1 right, 2 left, 3 top, 4 back, 5 guide,
# 6 start, 7 left stick, 8 right stick, 9 left shoulder, 10 right shoulder,
# 11-14 d-pad up/down/left/right, 15 misc (share / mic / capture).
const XBOX_BUTTONS := ["A", "B", "X", "Y", "View", "Xbox", "Menu", "LS", "RS", "LB", "RB",
	"D-Up", "D-Down", "D-Left", "D-Right", "Share"]
const PS4_BUTTONS := ["Cross", "Circle", "Square", "Triangle", "Share", "PS", "Options", "L3", "R3",
	"L1", "R1", "D-Up", "D-Down", "D-Left", "D-Right", "Mic"]
const PS_CLASSIC_BUTTONS := ["Cross", "Circle", "Square", "Triangle", "Select", "PS", "Start", "L3", "R3",
	"L1", "R1", "D-Up", "D-Down", "D-Left", "D-Right", "Analog"]
const SWITCH_BUTTONS := ["B", "A", "Y", "X", "-", "Home", "+", "LS", "RS", "L", "R",
	"D-Up", "D-Down", "D-Left", "D-Right", "Capture"]
const XBOX_TRIGGERS := ["LT", "RT"]
const PS_TRIGGERS := ["L2", "R2"]
const SWITCH_TRIGGERS := ["ZL", "ZR"]


## Works out which family a connected controller belongs to.
static func detect(device: int) -> int:
	var name := Input.get_joy_name(device).to_lower()
	var info := Input.get_joy_info(device)
	var vid := _to_int(info.get("vendor_id", 0))
	var pid := _to_int(info.get("product_id", 0))
	# PS2 adapters first: some of them report Sony-like names.
	for w in PS2_WORDS:
		if w in name:
			return Family.PS2
	if vid in VID_PS2_ADAPTERS:
		return Family.PS2
	if vid == VID_SONY:
		if pid in PID_PS3:
			return Family.PS3
		if pid in PID_PS5:
			return Family.PS5
		return Family.PS4
	if "dualsense" in name or "ps5" in name:
		return Family.PS5
	if "dualshock 4" in name or "ps4" in name or name == "wireless controller":
		return Family.PS4
	if "dualshock 3" in name or "ps3" in name or "sixaxis" in name or "playstation(r)3" in name \
			or "playstation 3" in name:
		return Family.PS3
	if vid == VID_MICROSOFT or "xbox" in name or "xinput" in name or "x-box" in name:
		return Family.XBOX
	if "nintendo" in name or "switch" in name or "pro controller" in name:
		return Family.SWITCH
	return Family.GENERIC


## True for every PlayStation generation.
static func is_playstation(family: int) -> bool:
	return family in [Family.PS2, Family.PS3, Family.PS4, Family.PS5]


## One line describing a controller, for the settings menu.
static func describe(device: int) -> String:
	var family := detect(device)
	var raw := Input.get_joy_name(device)
	var layout := "standard layout" if Input.is_joy_known(device) else "unknown layout - use SET UP"
	return "%s  -  %s  (%s)" % [FAMILY_NAMES[family], raw.left(28), layout]


## Display name of a joypad button for a given family.
static func button_name(index: int, family: int) -> String:
	var names: Array = XBOX_BUTTONS
	if family in [Family.PS4, Family.PS5]:
		names = PS4_BUTTONS
	elif family in [Family.PS2, Family.PS3]:
		names = PS_CLASSIC_BUTTONS
	elif family == Family.SWITCH:
		names = SWITCH_BUTTONS
	elif family == Family.GENERIC:
		return "Button %d" % index
	if index == JOY_BUTTON_TOUCHPAD and is_playstation(family):
		return "Touchpad"
	if index >= 0 and index < names.size():
		return names[index]
	return "Button %d" % index


## Display name of a joypad axis direction (sign = -1 or +1).
static func axis_name(axis: int, sign: float, family: int) -> String:
	var triggers: Array = XBOX_TRIGGERS
	if is_playstation(family):
		triggers = PS_TRIGGERS
	elif family == Family.SWITCH:
		triggers = SWITCH_TRIGGERS
	match axis:
		JOY_AXIS_LEFT_X:
			return "L-Stick Left" if sign < 0 else "L-Stick Right"
		JOY_AXIS_LEFT_Y:
			return "L-Stick Up" if sign < 0 else "L-Stick Down"
		JOY_AXIS_RIGHT_X:
			return "R-Stick Left" if sign < 0 else "R-Stick Right"
		JOY_AXIS_RIGHT_Y:
			return "R-Stick Up" if sign < 0 else "R-Stick Down"
		JOY_AXIS_TRIGGER_LEFT:
			return triggers[0]
		JOY_AXIS_TRIGGER_RIGHT:
			return triggers[1]
	return "Axis %d%s" % [axis, "-" if sign < 0 else "+"]


## get_joy_info() returns numbers on some platforms and strings on others.
static func _to_int(v: Variant) -> int:
	if v is int:
		return v
	if v is String:
		return (v as String).to_int()
	return 0
