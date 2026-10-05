shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D skin_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D ink_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 skin_tint : source_color = vec4(0.62,0.39,0.26,1.0);
void fragment(){
    vec4 ink = texture(ink_texture, UV);
    vec3 skin = texture(skin_texture, UV*2.0).rgb * skin_tint.rgb;
    ALBEDO = mix(skin, vec3(0.055,0.065,0.057), ink.a * 0.65);
    ROUGHNESS = 0.76;
}
