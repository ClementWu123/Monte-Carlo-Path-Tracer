vec3 squareToDiskUniform(vec2 sample) {
    float theta = TWO_PI * sample.y;
    float r = sqrt(sample.x);
    float x = r * cos(theta);
    float y = r * sin(theta);
    return vec3(x, y, 0.0);
}

vec3 squareToDiskConcentric(vec2 sample) {
    float x = 2.0 * sample.x - 1.0;
    float y = 2.0 * sample.y - 1.0;

    if (x == 0.0 && y == 0.0) {
        return vec3(0.0, 0.0, 0.0);
    }

    float phi, r;
    if (abs(x) > abs(y)) {
        r = x;
        phi = (PI / 4.0) * (y / x);
    } else {
        r = y;
        phi = (PI / 2.0) - (x / y) * (PI / 4.0);
    }

    return vec3(r * cos(phi), r * sin(phi), 0.0);
}

float squareToDiskPDF(vec3 sample) {
    return INV_PI;
}

vec3 squareToSphereUniform(vec2 sample) {
    float z = 1.0 - 2.0 * sample.x;
    float r = sqrt(max(0.0, 1.0 - z * z));
    float x = cos(TWO_PI * sample.y) * r;
    float y = sin(TWO_PI * sample.y) * r;
    return vec3(x, y, z);
}

float squareToSphereUniformPDF(vec3 sample) {
    return INV_FOUR_PI;
}

vec3 squareToSphereCapUniform(vec2 sample, float thetaMin) {
    float scale = (180.0 - thetaMin) / 180.0;
    float z = 1.0 - 2.0 * scale * sample.x;
    float r = sqrt(max(0.0, 1.0 - z * z));
    float x = cos(TWO_PI * sample.y) * r;
    float y = sin(TWO_PI * sample.y) * r;
    return vec3(x, y, z);
}

float squareToSphereCapUniformPDF(vec3 sample, float thetaMin) {
    float scale = (180.0 - thetaMin) / 180.0;
    return 1.0 / (2.0 * PI * (1.0 - cos(PI * scale)));
}

vec3 squareToHemisphereUniform(vec2 sample) {
    float z = sample.x;
    float r = sqrt(max(0.0, 1.0 - z * z));
    float x = cos(TWO_PI * sample.y) * r;
    float y = sin(TWO_PI * sample.y) * r;
    return vec3(x, y, z);
}

float squareToHemisphereUniformPDF(vec3 sample) {
    return INV_TWO_PI;
}

vec3 squareToHemisphereCosine(vec2 sample) {
    vec2 disk = vec2(squareToDiskConcentric(sample));
    float x = disk.x;
    float y = disk.y;
    float z = sqrt(max(0.0, 1.0 - x*x - y*y));
    return vec3(x, y, z);
}

float squareToHemisphereCosinePDF(vec3 sample) {
    return sample.z / PI;
}
