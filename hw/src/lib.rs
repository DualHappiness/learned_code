pub mod obj_loader;
pub mod rasterizer;
pub mod shader;
pub mod texture;
pub mod triangle;

use nalgebra::{Matrix4, Vector3, Vector4};

type Vector3f = Vector3<f32>;
pub fn get_view_matrix(eye_pos: Vector3<f32>) -> Matrix4<f32> {
    let translate = Matrix4::from_columns(&[
        Vector4::x(),
        Vector4::y(),
        Vector4::z(),
        Vector4::new(-eye_pos[0], -eye_pos[1], -eye_pos[2], 1.0),
    ]);
    translate
}

pub fn get_model_matrix(rotation_angle: f32) -> Matrix4<f32> {
    let angle = rotation_angle / 180.0 * std::f32::consts::PI;

    let translate = Matrix4::from_columns(&[
        Vector4::new(angle.cos(), angle.sin(), 0.0, 0.0),
        Vector4::new(-angle.sin(), angle.cos(), 0.0, 0.0),
        Vector4::z(),
        Vector4::w(),
    ]);

    translate
    // Matrix4::identity()
}

pub fn get_projection_matrix(
    eye_fov: f32,
    aspect_ratio: f32,
    z_near: f32,
    z_far: f32,
) -> Matrix4<f32> {
    let (n, f) = (z_near, z_far);
    let t = (eye_fov / 2.0 / 180.0 * std::f32::consts::PI).tan() * n.abs();
    let r = t * aspect_ratio;

    let orthographic_t = Matrix4::from_columns(&[
        Vector4::x(),
        Vector4::y(),
        Vector4::z(),
        Vector4::new(0.0, 0.0, -(n + f) / 2.0, 1.0),
    ]);
    let orthographic_s = Matrix4::from_columns(&[
        Vector4::new(1f32 / r, 0f32, 0f32, 0f32),
        Vector4::new(0f32, 1f32 / t, 0f32, 0f32),
        Vector4::new(0f32, 0f32, 2f32 / (n - f), 0f32),
        Vector4::w(),
    ]);

    let orthographic = orthographic_s * orthographic_t;

    let perspective_to_orthographic = Matrix4::from_columns(&[
        Vector4::new(n, 0f32, 0f32, 0f32),
        Vector4::new(0f32, n, 0f32, 0f32),
        Vector4::new(0f32, 0f32, n + f, 1f32),
        Vector4::new(0f32, 0f32, -n * f, 0f32),
    ]);

    #[cfg(feature = "show_print")]
    {
        println!("orthographic : {:?}", orthographic);
        println!("perspective_to_o: {:?}", perspective_to_orthographic);
    }
    orthographic * perspective_to_orthographic
}

pub fn vertex_shader(payload: &shader::VertexShaderPayload) -> Vector3<f32> {
    payload.position
}

pub fn normal_fragment_shader(payload: &shader::FragmentShaderPayload) -> Vector3<f32> {
    let return_color = (payload.normal.normalize() + Vector3::from_element(1f32)) / 2f32;
    return_color * 255f32
}

pub fn reflect(vec: &Vector3<f32>, axis: &Vector3<f32>) -> Vector3<f32> {
    let costheta = vec.dot(axis);
    (2f32 * costheta * axis - vec).normalize()
}

pub struct Light {
    position: Vector3f,
    intensity: Vector3f,
}

fn blinn_phone_calc(
    ka: Vector3f,
    kd: Vector3f,
    ks: Vector3f,
    color: Vector3f,
    point: Vector3f,
    normal: Vector3f,
) -> Vector3f {
    let l1: Light = Light {
        position: Vector3f::from_element(20f32),
        intensity: Vector3f::from_element(500f32),
    };
    let l2: Light = Light {
        position: Vector3f::new(-20f32, 20f32, 0f32),
        intensity: Vector3f::from_element(500f32),
    };
    let lights: Vec<Light> = vec![l1, l2];

    let ambient_light_intensity: Vector3f = Vector3f::from_element(10f32);

    let p: i32 = 150;

    let eye_pos: Vector3f = Vector3::new(0f32, 0f32, 10f32);
    Vector3f::from_element(0f32) * 255f32
}

pub fn texture_fragment_shader(payload: &shader::FragmentShaderPayload) -> Vector3f {
    let texture_color = match payload.texture {
        None => nalgebra::zero(),
        Some(texture) => texture.get_color(payload.tex_coords[0], payload.tex_coords[1]),
    };

    let ka = Vector3f::from_element(0.005);
    let kd = texture_color / 255f32;
    let ks = Vector3f::from_element(0.7937);

    let color = texture_color;
    let point = payload.view_pos;
    let normal = payload.normal;

    blinn_phone_calc(ka, kd, ks, color, point, normal)
}

pub fn phone_fragment_shader(payload: &shader::FragmentShaderPayload) -> Vector3f {
    let ka = Vector3f::from_element(0.005);
    let kd = payload.color;
    let ks = Vector3f::from_element(0.7937);

    let color = payload.color;
    let point = payload.view_pos;
    let normal = payload.normal;

    blinn_phone_calc(ka, kd, ks, color, point, normal)
}

pub fn displacement_fragment_shader(payload: &shader::FragmentShaderPayload) -> Vector3f {
    let ka = Vector3f::from_element(0.005);
    let kd = payload.color;
    let ks = Vector3f::from_element(0.7937);

    let color = payload.color;
    let point = payload.view_pos;
    let normal = payload.normal;

    // todo calc new normal and point
    blinn_phone_calc(ka, kd, ks, color, point, normal)
}

pub fn bump_fragment_shader(payload: &shader::FragmentShaderPayload) -> Vector3f {
    let ka = Vector3f::from_element(0.005);
    let kd = payload.color;
    let ks = Vector3f::from_element(0.7937);

    let color = payload.color;
    let point = payload.view_pos;
    let normal = payload.normal;

    // todo calc new normal and point
    blinn_phone_calc(ka, kd, ks, color, point, normal)
}
