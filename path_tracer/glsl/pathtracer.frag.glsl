const float FOVY = 19.5f * PI / 180.0;


Ray rayCast() {
    vec2 offset = vec2(rng(), rng());
    vec2 ndc = (vec2(gl_FragCoord.xy) + offset) / vec2(u_ScreenDims);
    ndc = ndc * 2.f - vec2(1.f);

    float aspect = u_ScreenDims.x / u_ScreenDims.y;
    vec3 ref = u_Eye + u_Forward;
    vec3 V = u_Up * tan(FOVY * 0.5);
    vec3 H = u_Right * tan(FOVY * 0.5) * aspect;
    vec3 p = ref + H * ndc.x + V * ndc.y;

    return Ray(u_Eye, normalize(p - u_Eye));
}


// TODO: Implement naive integration
vec3 Li_Naive(Ray ray) {
    vec3 throughput = vec3(1.f);
    for (int i = 0; i < MAX_DEPTH; ++i) {
        Intersection intersection = sceneIntersect(ray);
        if (intersection.t == INFINITY) {
            return vec3(0.);
        }
        if (dot(intersection.Le, intersection.Le) > 0.f) {
            return intersection.Le * throughput;
        }

        vec2 xi = vec2(rng(), rng());
        vec3 wo = -ray.direction;
        vec3 wi;
        float pdf;
        int sampledType;
        vec3 f = Sample_f(intersection, wo, xi, wi, pdf, sampledType);
        if (pdf == 0.f) {
            break;
        }
        ray = SpawnRay(ray.origin + intersection.t * ray.direction, wi);
        throughput = throughput * f * abs(dot(wi, intersection.nor)) / pdf;
    }
    return vec3(0.f);
}

vec3 Li_Direct(Ray ray) {
    Intersection intersection = sceneIntersect(ray);
    if(intersection.t == INFINITY){
        return vec3(0.);
    }
    else{
        if (dot(intersection.Le, intersection.Le) > 0.f) {
            return intersection.Le;
        }
        vec3 wiW = vec3(0.);
        float pdf;
        int chosenLightIdx, chosenLightID = 0;
        vec3 light = Sample_Li(ray.origin + intersection.t * ray.direction,
                                      intersection.nor, wiW, pdf, chosenLightIdx, chosenLightID);
        vec3 f = f(intersection, -ray.direction, wiW);
        if (pdf == 0.f) {
            return vec3(0.);
        }

        return f * light * abs(dot(wiW, intersection.nor)) / pdf;
    }
}


vec3 Li_DirectMIS(Ray ray) {
    vec3 accumulation = vec3(0.f);
    Intersection intersection = sceneIntersect(ray);
    if (dot(intersection.Le, intersection.Le) > 0.f) {
        return intersection.Le;
    }
    vec3 wiW;
    vec3 woW = -ray.direction;
    float pdf;
    int chosenLightIdx = 0;
    int chosenLightID = 0;
    vec3 light = Sample_Li(ray.origin + intersection.t * ray.direction,
                                 intersection.nor, wiW, pdf, chosenLightIdx, chosenLightID);
    vec3 f = f(intersection, woW, wiW);
    Ray shadow = SpawnRay(ray.origin + intersection.t * ray.direction, wiW);
    Intersection shadowIntersection = sceneIntersect(shadow);
    if (shadowIntersection.t != INFINITY && (pdf > 0.f)) {
        float brdf = Pdf(intersection, ray.direction, wiW);
        float weight1 = PowerHeuristic(1, pdf, 1, brdf);
        accumulation += weight1 * f * light * AbsDot(wiW, intersection.nor) / pdf;
    }

    vec2 xi = vec2(rng(), rng());
    wiW = vec3(0.);
    pdf = 0.;
    int sampledType = 0;
    float weight2 = 1.f;
    vec3 light2 = vec3(0.);
    vec3 f2 = Sample_f(intersection, woW, xi, wiW, pdf, sampledType);
    if(pdf == 0.f || isnan(pdf)) {
        return vec3(0.);
    }
    shadow = SpawnRay(ray.origin + intersection.t * ray.direction, wiW);
    shadowIntersection = sceneIntersect(shadow);
    float Pdf_Li = Pdf_Li(ray.origin + intersection.t * ray.direction,
                         intersection.nor, wiW, chosenLightIdx);
    if (Pdf_Li > 0.f) {
        weight2 = PowerHeuristic(1, pdf, 1, Pdf_Li);
        if (shadowIntersection.t != INFINITY && dot(shadowIntersection.Le, shadowIntersection.Le) > 0.f) {
            light2 = shadowIntersection.Le;
        }
    }
    accumulation += weight2 * f2 * light2 * AbsDot(wiW, intersection.nor) / pdf;
    if (any(isnan(accumulation))) {
        return vec3(0.f);
    }
    return accumulation;
}

vec3 sampleDirect(vec3 view_point, vec3 woW, Intersection intersection) {
     vec3 accumulation = vec3(0.f);

    if (intersection.t == INFINITY) {
        return vec3(0.f);
    }

    if (intersection.Le != vec3(0.f) && dot(intersection.nor, woW) > 0.f) {
        return intersection.Le;
    }

    vec3 wiW;
    float pdf;
    int chosenLightIdx;
    int chosenLightID;

    vec3 light = Sample_Li(view_point, intersection.nor, wiW, pdf, chosenLightIdx, chosenLightID);

    if (pdf != 0.f && light != vec3(0.f)) {
        vec3 brdf = f(intersection, woW, wiW);
        float brdf_pdf;

        if (brdf != vec3(0.f)) {
            brdf_pdf = Pdf(intersection, woW, wiW);
        }

        float w1 = PowerHeuristic(1, pdf, 1, brdf_pdf);

        if (brdf_pdf != 0.f) {
            accumulation += w1 * brdf * light * abs(dot(wiW, intersection.nor)) /  pdf;
        }
    }


    vec3 wiW_brdf;
    float brdf_pdf2;

    vec3 light2 = Sample_f(intersection, woW, vec2(rng(), rng()), wiW_brdf, brdf_pdf2, intersection.material.type);

    if (brdf_pdf2 != 0.f && light2 != vec3(0.f)) {
        float pdf2 = Pdf_Li(view_point, intersection.nor, wiW_brdf, chosenLightIdx);
        float w2;

        w2 = PowerHeuristic(1, brdf_pdf2, 1, pdf2);

        Ray shadow = SpawnRay(view_point, wiW_brdf);
        Intersection shadow_intersection = sceneIntersect(shadow);
        vec3 accumulation2;

        if (shadow_intersection.t != INFINITY) {
            accumulation2 = shadow_intersection.Le;
        }

        accumulation += w2 * light2 * accumulation2 * abs(dot(wiW_brdf, intersection.nor)) / brdf_pdf2;
    }

    if (any(isnan(accumulation))) {
        return vec3(0.f);
    }

    return accumulation;
}

vec3 Li_Full(Ray ray) {
    vec3 throughput = vec3(1.f);
    vec3 accumulation = vec3(0.f);
    bool intersectSpecular = false;

    for (int i = 0; i < MAX_DEPTH; i++) {
        Intersection intersection = sceneIntersect(ray);
        bool isSpecular = intersection.material.type == SPEC_REFL || intersection.material.type == SPEC_TRANS
                || intersection.material.type == SPEC_GLASS;

        if (intersection.t == INFINITY) {
            return accumulation + throughput * texture(u_EnvironmentMap, sampleSphericalMap(ray.direction)).rgb;
        }

        if(dot(intersection.Le, intersection.Le) > 0.f) {
            if(i == 0 || intersectSpecular) {
                return accumulation + intersection.Le * throughput;
            }
            return accumulation;
        }

        vec3 intersect = ray.origin + ray.direction * intersection.t;
        vec3 direct = vec3(0.);

        if (isSpecular) {
            intersectSpecular = true;
        } else {
            intersectSpecular = false;
            direct = sampleDirect(intersect, -ray.direction, intersection);

            if(any(isnan(direct))) {
                direct = vec3(0.f);
            }
        }

        vec3 wiW;
        float pdf;
        vec3 indirect = Sample_f(intersection, -ray.direction, vec2(rng(), rng()), wiW, pdf, intersection.material.type);

        if(pdf == 0.f || isnan(pdf)) {
            return accumulation;
        }

        accumulation += throughput * direct;
        throughput *= indirect * abs(dot(wiW, intersection.nor)) / pdf;
        ray = SpawnRay(intersect, wiW);
    }

    return accumulation;
}

void main()
{
    seed = uvec2(u_Iterations, u_Iterations + 1) * uvec2(gl_FragCoord.xy);

    Ray ray = rayCast();

    // vec3 thisIterationColor = Li_Naive(ray);
    // vec3 thisIterationColor = Li_Direct(ray);
    // vec3 thisIterationColor = Li_DirectMIS(ray);
    vec3 thisIterationColor = Li_Full(ray);
    vec3 prevAccumulatedColor = texture(u_AccumImg, gl_FragCoord.xy / u_ScreenDims).rgb;
    out_Col = vec4(mix(prevAccumulatedColor, thisIterationColor, (1.f/u_Iterations)), 1.f);

}
