shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D skin_texture : source_color, filter_linear_mipmap, repeat_enable;
float hash(vec2 p){return fract(sin(dot(p,vec2(12.9898,78.233)))*43758.5453);}
void fragment(){
    vec3 skin=texture(skin_texture,UV*vec2(2.0,1.0)).rgb*vec3(.84,.58,.42);
    float center=min(UV.x,1.0-UV.x);
    float front=1.0-smoothstep(.18,.28,center);
    float beard=smoothstep(.68,.76,UV.y)*(1.0-smoothstep(.96,1.0,UV.y))*front;
    float stubble=step(.74,hash(floor(UV*vec2(520.0,350.0))));
    float moustache=(1.0-smoothstep(.025,.07,center))*smoothstep(.66,.69,UV.y)*(1.0-smoothstep(.71,.74,UV.y));
    ALBEDO=mix(skin,vec3(.07,.045,.03),clamp((beard*.23+moustache*.30)*stubble,0.0,.8));
    ROUGHNESS=.73;
}
