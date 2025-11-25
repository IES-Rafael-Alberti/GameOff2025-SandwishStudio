// Sprite Particle Explosion Shader made in Godot 4.2.1  
// port of PlayWithFurcifers shader https://www.youtube.com/watch?v=D7XSL0zBOwI
// Ported by Mopifish
shader_type particles;
render_mode disable_velocity;

// Tinte aleatorio entre estos dos colores
uniform vec4 tint_color_a = vec4(1.0, 0.4, 0.3, 1.0); // rojizo
uniform vec4 tint_color_b = vec4(1.0, 1.0, 0.3, 1.0); // amarillento

uniform float spread = 180.0;
uniform float inherit_emitter_velocity_ratio = 0.0;
uniform float initial_linear_velocity_min = 200.0; // sube estos para explosion más grande
uniform float initial_linear_velocity_max = 260.0;

uniform float orbit_velocity_min;
uniform float orbit_velocity_max;
uniform float radial_velocity_min;
uniform float radial_velocity_max;
uniform float linear_accel_min;
uniform float linear_accel_max;
uniform float radial_accel_min;
uniform float radial_accel_max;
uniform float tangent_accel_min;
uniform float tangent_accel_max;
uniform float damping_min;
uniform float damping_max;
uniform float scale_min = 1.0;
uniform float scale_max = 1.0;
uniform float lifetime_randomness;
uniform vec3 emission_shape_offset = vec3(0.0);
uniform vec3 emission_shape_scale = vec3(1.0);
uniform vec3 emission_box_extents = vec3(100.0, 100.0, 0.0);
uniform sampler2D sprite : repeat_disable;

float rand_from_seed(inout uint seed) {
	int k;
	int s = int(seed);
	if (s == 0) {
		s = 305420679;
	}
	k = s / 127773;
	s = 16807 * (s - k * 127773) - 2836 * k;
	if (s < 0) {
		s += 2147483647;
	}
	seed = uint(s);
	return float(seed % uint(65536)) / 65535.0;
}

float rand_from_seed_m1_p1(inout uint seed) {
	return rand_from_seed(seed) * 2.0 - 1.0;
}

uint hash(uint x) {
	x = ((x >> uint(16)) ^ x) * uint(73244475);
	x = ((x >> uint(16)) ^ x) * uint(73244475);
	x = (x >> uint(16)) ^ x;
	return x;
}

struct DisplayParameters {
	vec3 scale;
	float lifetime;
};

struct DynamicsParameters {
	float initial_velocity_multiplier;
	float radial_velocity;
	float orbit_velocity;
};

struct PhysicalParameters {
	float linear_accel;
	float radial_accel;
	float tangent_accel;
	float damping;
};

void calculate_initial_physical_params(inout PhysicalParameters params, inout uint alt_seed) {
	params.linear_accel = mix(linear_accel_min, linear_accel_max, rand_from_seed(alt_seed));
	params.radial_accel = mix(radial_accel_min, radial_accel_max, rand_from_seed(alt_seed));
	params.tangent_accel = mix(tangent_accel_min, tangent_accel_max, rand_from_seed(alt_seed));
	params.damping = mix(damping_min, damping_max, rand_from_seed(alt_seed));
}

void calculate_initial_dynamics_params(inout DynamicsParameters params, inout uint alt_seed) {
	params.initial_velocity_multiplier = mix(initial_linear_velocity_min, initial_linear_velocity_max, rand_from_seed(alt_seed));
	params.radial_velocity = mix(radial_velocity_min, radial_velocity_max, rand_from_seed(alt_seed));
	params.orbit_velocity = mix(orbit_velocity_min, orbit_velocity_max, rand_from_seed(alt_seed));
}

void calculate_initial_display_params(inout DisplayParameters params, inout uint alt_seed) {
	float pi = 3.14159;
	float degree_to_rad = pi / 180.0;
	params.scale = vec3(mix(scale_min, scale_max, rand_from_seed(alt_seed)));
	params.scale = sign(params.scale) * max(abs(params.scale), 0.001);
	params.lifetime = (1.0 - lifetime_randomness * rand_from_seed(alt_seed));
}

// Todas las partículas empiezan exactamente en el origen del emisor (0,0,0)
vec3 calculate_initial_position(inout uint alt_seed) {
	vec3 pos = vec3(0.0, 0.0, 0.0);
	return pos * emission_shape_scale + emission_shape_offset;
}

// Dirección aleatoria 2D dentro de un cono de ángulo "spread"
vec3 get_random_direction_from_spread(inout uint alt_seed, float spread_angle) {
	float pi = 3.14159;
	float degree_to_rad = pi / 180.0;

	float half_spread = spread_angle * 0.5 * degree_to_rad;
	float ang = rand_from_seed_m1_p1(alt_seed) * half_spread;

	return vec3(cos(ang), sin(ang), 0.0);
}

vec3 process_orbit_displacement(DynamicsParameters param, float lifetime, inout uint alt_seed,
	mat4 transform, mat4 emission_transform, float delta, float total_lifetime) {
	if (abs(param.orbit_velocity) < 0.01 || delta < 0.001) {
		return vec3(0.0);
	}

	vec3 displacement = vec3(0.0);
	float pi = 3.14159;
	float degree_to_rad = pi / 180.0;
	float orbit_amount = param.orbit_velocity;
	if (orbit_amount != 0.0) {
		vec3 pos = transform[3].xyz;
		vec3 org = emission_transform[3].xyz;
		vec3 diff = pos - org;
		float ang = orbit_amount * pi * 2.0 * delta;
		mat2 rot = mat2(vec2(cos(ang), -sin(ang)), vec2(sin(ang), cos(ang)));
		displacement.xy -= diff.xy;
		displacement.xy += rot * diff.xy;
	}
	return (emission_transform * vec4(displacement / delta, 0.0)).xyz;
}

vec3 process_radial_displacement(DynamicsParameters param, float lifetime, inout uint alt_seed,
	mat4 transform, mat4 emission_transform, float delta) {
	return vec3(0.0);
}

void start() {
	uint base_number = NUMBER;
	uint alt_seed = hash(base_number + uint(1) + RANDOM_SEED);

	DisplayParameters params;
	calculate_initial_display_params(params, alt_seed);
	DynamicsParameters dynamic_params;
	calculate_initial_dynamics_params(dynamic_params, alt_seed);
	PhysicalParameters physics_params;
	calculate_initial_physical_params(physics_params, alt_seed);

	if (rand_from_seed(alt_seed) > AMOUNT_RATIO) {
		ACTIVE = false;
	}

	if (RESTART_CUSTOM) {
		CUSTOM = vec4(0.0);
		CUSTOM.w = params.lifetime;
	}

	if (RESTART_ROT_SCALE) {
		TRANSFORM[0].xyz = vec3(1.0, 0.0, 0.0);
		TRANSFORM[1].xyz = vec3(0.0, 1.0, 0.0);
		TRANSFORM[2].xyz = vec3(0.0, 0.0, 1.0);
	}

	if (RESTART_POSITION) {
		TRANSFORM[3].xyz = calculate_initial_position(alt_seed);
		TRANSFORM = EMISSION_TRANSFORM * TRANSFORM;
	}
	if (RESTART_VELOCITY) {
		VELOCITY = get_random_direction_from_spread(alt_seed, spread)
			* dynamic_params.initial_velocity_multiplier;
	}

	VELOCITY = (EMISSION_TRANSFORM * vec4(VELOCITY, 0.0)).xyz;
	VELOCITY += EMITTER_VELOCITY * inherit_emitter_velocity_ratio;

	VELOCITY.z = 0.0;
	TRANSFORM[3].z = 0.0;

	// --- Color de la partícula ---
	vec2 particlePosition = TRANSFORM[3].xy;
	vec2 texture5 = vec2(textureSize(sprite, 0));

	vec4 spriteColor = texture(sprite, particlePosition / texture5 + vec2(0.5, 0.5));

	// Tinte aleatorio entre A y B
	float tint_t = rand_from_seed(alt_seed);
	vec4 tint = mix(tint_color_a, tint_color_b, tint_t);

	COLOR = vec4(spriteColor.rgb * tint.rgb, spriteColor.a * tint.a);

	if (COLOR.a == 0.0) {
		ACTIVE = false;
	}
}

void process() {
	uint base_number = NUMBER;
	uint alt_seed = hash(base_number + uint(1) + RANDOM_SEED);

	DisplayParameters params;
	calculate_initial_display_params(params, alt_seed);
	DynamicsParameters dynamic_params;
	calculate_initial_dynamics_params(dynamic_params, alt_seed);
	PhysicalParameters physics_params;
	calculate_initial_physical_params(physics_params, alt_seed);

	CUSTOM.y += DELTA / LIFETIME;
	CUSTOM.y = mix(CUSTOM.y, 1.0, INTERPOLATE_TO_END);
	float lifetime_percent = CUSTOM.y / params.lifetime;
	if (CUSTOM.y > CUSTOM.w) {
		ACTIVE = false;
	}

	vec3 controlled_displacement = vec3(0.0);

	controlled_displacement += process_orbit_displacement(dynamic_params, lifetime_percent, alt_seed,
		TRANSFORM, EMISSION_TRANSFORM, DELTA, params.lifetime * LIFETIME);

	// radial displacement ahora es 0
	controlled_displacement += process_radial_displacement(dynamic_params, lifetime_percent, alt_seed,
		TRANSFORM, EMISSION_TRANSFORM, DELTA);

	vec3 force = vec3(0.0);
	{
		vec3 pos = TRANSFORM[3].xyz;

		// linear accel
		force += length(VELOCITY) > 0.0 ? normalize(VELOCITY) * physics_params.linear_accel : vec3(0.0);

		// radial accel (si la usas, seguirá estando "bien" porque la posición
		// ya se ha movido desde el centro)
		vec3 org = EMISSION_TRANSFORM[3].xyz;
		vec3 diff = pos - org;
		force += length(diff) > 0.0 ? normalize(diff) * physics_params.radial_accel : vec3(0.0);

		// tangente
		float tangent_accel_val = physics_params.tangent_accel;
		force += length(diff.yx) > 0.0 ? vec3(normalize(diff.yx * vec2(-1.0, 1.0)), 0.0) * tangent_accel_val : vec3(0.0);

		force += ATTRACTOR_FORCE;

		force.z = 0.0;
		VELOCITY += force * DELTA;
	}
	{
		if (physics_params.damping > 0.0) {
			float v = length(VELOCITY);
			v -= physics_params.damping * DELTA;
			if (v < 0.0) {
				VELOCITY = vec3(0.0);
			} else {
				VELOCITY = normalize(VELOCITY) * v;
			}
		}
	}

	vec3 final_velocity = controlled_displacement + VELOCITY;

	final_velocity.z = 0.0;
	TRANSFORM[3].xyz += final_velocity * DELTA;

	TRANSFORM[0] = vec4(cos(CUSTOM.x), -sin(CUSTOM.x), 0.0, 0.0);
	TRANSFORM[1] = vec4(sin(CUSTOM.x), cos(CUSTOM.x), 0.0, 0.0);
	TRANSFORM[2] = vec4(0.0, 0.0, 1.0, 0.0);
	TRANSFORM[3].z = 0.0;

	// Apply Scale
	TRANSFORM[0].xyz *= sign(params.scale.x) * max(abs(params.scale.x), 0.001);
	TRANSFORM[1].xyz *= sign(params.scale.y) * max(abs(params.scale.y), 0.001);
	TRANSFORM[2].xyz *= sign(params.scale.z) * max(abs(params.scale.z), 0.001);

	if (CUSTOM.y > CUSTOM.w) {
		ACTIVE = false;
	}

	if (COLOR.a > 0.0) {
		COLOR.a -= 1.0 / LIFETIME * DELTA;
	}
}