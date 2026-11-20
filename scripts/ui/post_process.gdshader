shader_type canvas_item;
// Full-screen colour adjustment drawn on top of everything by the Settings
// autoload. It reads what is already on screen and re-colours it.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float brightness = 1.0;   // multiplies the colour (1 = unchanged)
uniform float contrast = 1.0;     // pushes colours away from / towards grey
uniform float gamma = 1.0;        // >1 lifts the shadows, <1 deepens them
uniform float scanlines = 0.0;    // 0..1 darkness of every other game pixel row
uniform float vignette = 0.0;     // 0..1 darkening towards the corners

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	c = (c - 0.5) * contrast + 0.5;
	c *= brightness;
	c = pow(max(c, vec3(0.0)), vec3(1.0 / gamma));
	// 216 = the game's pixel height, so one dark line per game pixel row.
	if (fract(SCREEN_UV.y * 216.0) > 0.5) {
		c *= 1.0 - scanlines;
	}
	vec2 d = SCREEN_UV - 0.5;
	c *= 1.0 - vignette * dot(d, d) * 1.6;
	COLOR = vec4(c, 1.0);
}
