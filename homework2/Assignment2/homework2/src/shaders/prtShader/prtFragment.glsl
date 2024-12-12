
#ifdef GL_ES
precision mediump float;
#endif

varying highp vec3 vColor;

vec3 LineartoSRGB(vec3 color){
    vec3 result;

    for (int i=0; i<3; ++i) {
        if (color[i] <= 0.0031308)
            result[i] = 12.92 * color[i];
        else
            result[i] = (1.0 + 0.055) * pow(color[i], 1.0/2.4) - 0.055;
    }

    return result;
}

void main(){
    // gl_FragColor = vec4(1.0, 0.0, 0.0, 1.0);


    gl_FragColor = vec4(LineartoSRGB(vColor), 1.0);
}