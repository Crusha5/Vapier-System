shader_type sky;
// Himmel von Veyra: Verlauf je Tageszeit, Sonne, Mond, Sterne und das rote Glühen des Schleiers am Horizont.
uniform vec3 top_color : source_color = vec3(0.05, 0.07, 0.12);
uniform vec3 horizon_color : source_color = vec3(0.18, 0.15, 0.17);
uniform vec3 sun_dir = vec3(0.0, 0.5, -1.0);
uniform vec3 sun_color : source_color = vec3(1.0, 0.8, 0.6);
uniform float night = 0.0;
uniform vec3 veil_color : source_color = vec3(0.9, 0.12, 0.15);
uniform float veil_strength = 1.0;

float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }

void sky() {
	vec3 d = EYEDIR;
	float up = clamp(d.y, -1.0, 1.0);
	vec3 c = mix(horizon_color, top_color, smoothstep(-0.05, 0.55, up));
	// Schleier: rotes Wabern am Horizont, rundum
	float ang = atan(d.x, d.z);
	float band = exp(-pow((up - 0.04) * 9.0, 2.0));
	float flick = 0.55 + 0.45 * sin(ang * 7.0 + TIME * 0.4) * sin(ang * 13.0 - TIME * 0.27);
	c += veil_color * band * flick * (0.12 + 0.5 * night);
	// Sonne
	float sd = dot(d, normalize(sun_dir));
	c += sun_color * pow(max(sd, 0.0), 900.0) * 6.0 * (1.0 - night);
	c += sun_color * pow(max(sd, 0.0), 12.0) * 0.25 * (1.0 - night);
	// Mond (gegenüber der Sonne)
	float md = dot(d, normalize(-sun_dir + vec3(0.0, 0.25, 0.0)));
	c += vec3(0.75, 0.82, 1.0) * smoothstep(0.9993, 0.9996, md) * night;
	c += vec3(0.25, 0.3, 0.45) * pow(max(md, 0.0), 40.0) * 0.4 * night;
	// Sterne
	if (up > 0.0) {
		vec3 g = floor(d * 220.0);
		float s = step(0.9975, hash(g));
		c += vec3(0.9, 0.9, 1.0) * s * night * smoothstep(0.0, 0.25, up) * (0.6 + 0.4 * sin(TIME * 3.0 + hash(g) * 50.0));
	}
	COLOR = c;
}
