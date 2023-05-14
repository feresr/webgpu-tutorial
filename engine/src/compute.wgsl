const pi = 3.14159265359;

// write to a buffer or texture
@group(0) @binding(0)
var out_texture: texture_storage_2d<rgba8unorm, write>;
@group(0) @binding(1)
var<uniform> time: f32; 

// Image
const image_width = 800;
const image_height = 600;
const aspect : f32 = 1.333333; // 800.0 / 600.0; // todo 

// Camera
const viewport_height = 2.0;

const focal_length = 1.0;

struct HitRecord {
    hit: bool,
    p: vec3<f32>,
    normal: vec3<f32>,
    t: f32,
    front_face: bool,
}

struct Sphere {
    center: vec3<f32>,
    radius: f32
}

fn hit_sphere(sphere: Sphere, ray: Ray, t_min: f32, t_max: f32) -> HitRecord {
    var oc = ray.origin - sphere.center;
    var a = pow(length(ray.dir), 2.0);
    var half_b = dot(oc, ray.dir);
    var c = pow(length(oc), 2.0) - pow(sphere.radius, 2.0);

    var hr: HitRecord;
    hr.hit = false;

    var discriminant = half_b * half_b - a * c;
    if discriminant < 0.0 { return hr; }

    var sqrtd = sqrt(discriminant);


    var root = (-half_b - sqrtd) / a;
    if root < t_min || t_max < root {
        root = (-half_b + sqrtd) / a;
        if root < t_min || t_max < root {
            return hr;
        }
    }
    hr.hit = true;
    hr.t = root;
    hr.p = at(ray, root);

    var outward_normal = (hr.p - sphere.center) / sphere.radius;
    hr.front_face = dot(ray.dir, outward_normal) < 0.0;
    if hr.front_face { hr.normal = outward_normal; } else { hr.normal = -outward_normal; };
    return hr;
}

fn hit_spheres(ray: Ray, s: array<Sphere, 10>) -> HitRecord {
    var closest_so_far = 999999.00;
    var first = hit_sphere(s[0], ray, 0.0000, closest_so_far);
    if first.hit {
        closest_so_far = first.t;
    }
    var second = hit_sphere(s[1], ray, 0.0000, closest_so_far);
    if second.hit {
        closest_so_far = second.t;
        first = second;
    }
    // first = hit_sphere(s[2], ray, 0.0, closest_so_far);
    // if (first.hit) {
    //     closest_so_far = first.t;
    // }
    // first = hit_sphere(s[3], ray, 0.0, closest_so_far);
    // if (first.hit) {
    //     closest_so_far = first.t;
    // }

    return first;
}

fn ray_color(ray: Ray, s: array<Sphere, 10>, depth: u32) -> vec3<f32> {
    var d = depth;
    var result = vec3<f32>(1.0, 1.0, 1.0);
    var rin: Ray = ray;
    while true {
        if d <= 0u {
            return vec3<f32>(0.0, 0.0, 0.0);
        }
        var hit = hit_spheres(rin, s);
        if hit.hit {
            var targ = hit.p + random_in_hemisphere(hit.normal);
            rin = Ray(hit.p, targ - hit.p);
            d = d - 1u;
            result *= 0.5;
        } else {
            var unit_direction = normalize(rin.dir);
            var t = 0.5 * (unit_direction.y + 1.0);
            result *= (vec3<f32>(1.0 - t) + t * vec3<f32>(0.1, 0.0, 0.1));
            return result;
        }
    }
    return result;
}

struct Ray {
    origin: vec3<f32>,
    dir: vec3<f32>
};

fn at(ray: Ray, t: f32) -> vec3<f32> {
    return ray.origin + t * ray.dir;
}

fn hit(ray: Ray, min: f32, max: f32) -> HitRecord {
    var hr: HitRecord;
    return hr;
}


// A psuedo random number. Initialized with init_rand(), updated with rand().
var<private> rnd : vec3<u32>;

// Initializes the random number generator.
fn init_rand(invocation_id: vec3<u32>) {
    var A: vec3<u32> = vec3<u32>(1741651u * 1009u, 140893u * 1609u * 13u, 6521u * 983u * 7u * 2u);
    rnd = (invocation_id * A) ^ vec3<u32>(u32(time), u32(time), u32(time));
}

fn rand() -> f32 {
    var C = vec3<u32>(60493u * 9377u, 11279u * 2539u * 23u, 7919u * 631u * 5u * 3u);
    rnd = (rnd * C) ^ (rnd.yzx >> vec3<u32>(4u));
    return f32(rnd.x ^ rnd.y) / f32(0x7fffffff);
}

// Returns a random point within a unit sphere centered at (0,0,0).
fn rand_unit_sphere() -> vec3<f32> {
    var u = rand();
    var v = rand();
    var theta = u * 2.0 * pi;
    var phi = acos(2.0 * v - 1.0);
    var r = pow(rand(), 1.0 / 3.0);
    var sin_theta = sin(theta);
    var cos_theta = cos(theta);
    var sin_phi = sin(phi);
    var cos_phi = cos(phi);
    var x = r * sin_phi * sin_theta;
    var y = r * sin_phi * cos_theta;
    var z = r * cos_phi;
    return vec3<f32>(x, y, z);
}

fn rand_concentric_disk() -> vec2f {
    let u = vec2<f32>(rand(), rand());
    let uOffset = 2.f * u - vec2<f32>(1.0, 1.0);

    if uOffset.x == 0.0 && uOffset.y == 0.0 {
        return vec2<f32>(0.0, 0.0);
    }

    var theta = 0.0;
    var r = 0.0;
    if abs(uOffset.x) > abs(uOffset.y) {
        r = uOffset.x;
        theta = (pi / 4.0) * (uOffset.y / uOffset.x);
    } else {
        r = uOffset.y;
        theta = (pi / 2.0) - (pi / 4.0) * (uOffset.x / uOffset.y);
    }
    return r * vec2<f32>(cos(theta), sin(theta));
}

fn rand_cosine_weighted_hemisphere() -> vec3f {
    let d = rand_concentric_disk();
    let z = sqrt(max(0.0, 1.0 - d.x * d.x - d.y * d.y));
    return vec3<f32>(d.x, d.y, z);
}

fn random_in_hemisphere(normal: vec3f) -> vec3f {
    var in_unit_sphere = rand_cosine_weighted_hemisphere();
    if dot(in_unit_sphere, normal) > 0.0 {
        return in_unit_sphere;
    } else {

        return -in_unit_sphere;
    }
}

@compute @workgroup_size(16 , 16)
fn main(@builtin(global_invocation_id) global_id: vec3u) {
    init_rand(global_id);
    var viewport_width: f32 = aspect * viewport_height;
    var origin = vec3<f32>(0.0, 0.0, 0.0);
    var horizontal = vec3<f32>(viewport_width, 0.0, 0.0);
    var vertical = vec3<f32>(0.0, viewport_height, 0.0);
    var lower_left_corner = origin - (horizontal / 2.0) - (vertical / 2.0) - vec3<f32>(0.0, 0.0, focal_length);

    var shpere: Sphere;
    shpere.center = vec3<f32>(0.0, 0.0, -1.0f);
    shpere.radius = 0.5;
    var floor: Sphere;
    floor.center = vec3<f32>(0.0, -100.5, -1.0);
    floor.radius = 100.0;

    var a: array<Sphere, 10>;
    a[0] = shpere;
    a[1] = floor;

    var color = vec3<f32>(0.0, 0.0, 0.0);
    var ray_per_pixel = 12;
    for (var i = 0; i < ray_per_pixel; i++) {
        var r: Ray;
        r.origin = origin;
        let xx = (f32(global_id.x) + rand()) / f32(image_width);
        let yy = (f32(global_id.y) + rand()) / f32(image_height);
        r.dir = lower_left_corner + xx * horizontal + yy * vertical - origin;
        color += ray_color(r, a, 10u);
    }

    // color = normalize(color);
    var scale = 1.0 / f32(ray_per_pixel);
    color = sqrt(color * scale);
    color = clamp(color, vec3<f32>(0.0), vec3<f32>(1.0));

    textureStore(out_texture, vec2<u32>(global_id.x, global_id.y), vec4<f32>(color.xyz, 1.0));
    // textureStore(out_texture, vec2<u32>(global_id.x, global_id.y), vec4<f32>(vec3<f32>(rand()), 1.0));
}
