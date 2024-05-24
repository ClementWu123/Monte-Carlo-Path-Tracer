
vec2 normalize_uv = vec2(0.1591, 0.3183);
vec2 sampleSphericalMap(vec3 v) {
    // U is in the range [-PI, PI], V is [-PI/2, PI/2]
    vec2 uv = vec2(atan(v.z, v.x), asin(v.y));
    // Convert UV to [-0.5, 0.5] in U&V
    uv *= normalize_uv;
    // Convert UV to [0, 1]
    uv += 0.5;
    return uv;
}

vec3 sampleFromInsideSphere(vec2 xi, out float pdf) {
//    Point3f pObj = WarpFunctions::squareToSphereUniform(xi);

//    Intersection it;
//    it.normalGeometric = glm::normalize( transform.invTransT() *pObj );
//    it.point = Point3f(transform.T() * glm::vec4(pObj.x, pObj.y, pObj.z, 1.0f));

//    *pdf = 1.0f / Area();

//    return it;
    return vec3(0.);
}

#if N_AREA_LIGHTS
vec3 DirectSampleAreaLight(int idx,
                           vec3 view_point, vec3 view_nor,
                           int num_lights,
                           out vec3 wiW, out float pdf) {
    AreaLight light = areaLights[idx];
    int type = light.shapeType;
    Ray shadowRay;

    if(type == RECTANGLE) {
        // TODO: Paste your code from hw03 here
        vec3 xi = vec3(rng(), rng(), 0.);
        xi.x = xi.x * 2. - 1.;
        xi.y = xi.y * 2. - 1.;
        xi = vec3(light.transform.T * vec4(xi, 1.));
        vec3 normal = light.transform.invTransT * vec3(0., 0., 1.);
        float area = 4 * light.transform.scale.x * light.transform.scale.y;
        pdf = float(1.f / area);
        wiW = normalize(xi - view_point);
        if (max(dot(normal, -wiW), 0) == 0.) {
            pdf = 0.;
        } else {
            pdf *= distance(xi, view_point) * distance(xi, view_point) / max(dot(normal, -wiW), 0.);
        }
        Ray ray = SpawnRay(view_point, wiW);
        Intersection isect = sceneIntersect(ray);
        if (dot(isect.Le, isect.Le) > 0.) {
            return num_lights * light.Le;
        } else {
            return vec3(0.);
        }
    }
    else if(type == SPHERE) {
        Transform tr = areaLights[idx].transform;

        vec2 xi = vec2(rng(), rng());

        vec3 center = vec3(tr.T * vec4(0., 0., 0., 1.));
        vec3 centerToRef = normalize(center - view_point);
        vec3 tan, bit;

        coordinateSystem(centerToRef, tan, bit);

        vec3 pOrigin;
        if(dot(center - view_point, view_nor) > 0) {
            pOrigin = view_point + view_nor * RayEpsilon;
        }
        else {
            pOrigin = view_point - view_nor * RayEpsilon;
        }

        // Inside the sphere
        if(dot(pOrigin - center, pOrigin - center) <= 1.f) // Radius is 1, so r^2 is also 1
            return sampleFromInsideSphere(xi, pdf);

        float sinThetaMax2 = 1 / dot(view_point - center, view_point - center); // Again, radius is 1
        float cosThetaMax = sqrt(max(0.0f, 1.0f - sinThetaMax2));
        float cosTheta = (1.0f - xi.x) + xi.x * cosThetaMax;
        float sinTheta = sqrt(max(0.f, 1.0f- cosTheta * cosTheta));
        float phi = xi.y * TWO_PI;

        float dc = distance(view_point, center);
        float ds = dc * cosTheta - sqrt(max(0.0f, 1 - dc * dc * sinTheta * sinTheta));

        float cosAlpha = (dc * dc + 1 - ds * ds) / (2 * dc * 1);
        float sinAlpha = sqrt(max(0.0f, 1.0f - cosAlpha * cosAlpha));

        vec3 nObj = sinAlpha * cos(phi) * -tan + sinAlpha * sin(phi) * -bit + cosAlpha * -centerToRef;
        vec3 pObj = vec3(nObj); // Would multiply by radius, but it is always 1 in object space

        shadowRay = SpawnRay(view_point, normalize(vec3(tr.T * vec4(pObj, 1.0f)) - view_point));
        wiW = shadowRay.direction;
        pdf = 1.0f / (TWO_PI * (1 - cosThetaMax));
        pdf /= tr.scale.x * tr.scale.x;
    }

    Intersection isect = sceneIntersect(shadowRay);
    if(isect.obj_ID == areaLights[idx].ID) {
        // Multiply by N+1 to account for sampling it 1/(N+1) times.
        // +1 because there's also the environment light
        return num_lights * areaLights[idx].Le;
    }
}
#endif

#if N_POINT_LIGHTS
vec3 DirectSamplePointLight(int idx,
                            vec3 view_point, int num_lights,
                            out vec3 wiW, out float pdf) {
    PointLight light = pointLights[idx];
    // TODO: Paste your code from hw03 here
    wiW = normalize(vec3(light.pos - view_point));
    pdf = 1.f;
    Ray shadow = SpawnRay(view_point, wiW);
    Intersection intersection = sceneIntersect(shadow);
    if (intersection.t >= distance(light.pos, view_point)) {
        float dist = distance(light.pos, view_point);
        float squaredDist = dist * dist;
        return light.Le / squaredDist * num_lights;
    } else {
        return vec3(0.);
    }
}
#endif

#if N_SPOT_LIGHTS
vec3 DirectSampleSpotLight(int idx,
                           vec3 view_point, int num_lights,
                           out vec3 wiW, out float pdf) {
    SpotLight light = spotLights[idx];
    // TODO: Paste your code from hw03 here
    vec3 pos = vec3(light.transform.T * vec4(0., 0., 0., 1.));
    wiW = normalize(vec3(pos - view_point));
    vec3 normal = light.transform.invTransT * vec3(0., 0., 1.);
    float degree = degrees(acos(dot(normal, -wiW)));
    pdf = 1.f;

    if (degree < light.outerAngle) {
        float reduction = 0.f;
        if (degree > light.innerAngle) {
            reduction = 1 - smoothstep(light.innerAngle, light.outerAngle, degree);
        } else {
            reduction = 1.f;
        }

        Ray shadow = SpawnRay(view_point, wiW);
        Intersection intersection = sceneIntersect(shadow);

        if (intersection.t <= length(view_point - pos)) {
            return vec3(0.);
        } else {
            return reduction * num_lights * light.Le / (length(view_point - pos) * length(view_point - pos));
        }
    }
    return vec3(0.);
}
#endif

vec3 Sample_Li(vec3 view_point, vec3 nor,
                       out vec3 wiW, out float pdf,
                       out int chosenLightIdx,
                       out int chosenLightID) {
    // Choose a random light from among all of the
    // light sources in the scene, including the environment light
    int num_lights = N_LIGHTS;
#define ENV_MAP 0
#if ENV_MAP
    int num_lights = N_LIGHTS + 1;
#endif
    int randomLightIdx = int(rng() * num_lights);
    chosenLightIdx = randomLightIdx;
    // Chose an area light
    if(randomLightIdx < N_AREA_LIGHTS) {
#if N_AREA_LIGHTS
        chosenLightID = areaLights[chosenLightIdx].ID;
        return DirectSampleAreaLight(randomLightIdx, view_point, nor, num_lights, wiW, pdf);
#endif
    }
    // Chose a point light
    else if(randomLightIdx < N_AREA_LIGHTS + N_POINT_LIGHTS) {
#if N_POINT_LIGHTS
        chosenLightID = pointLights[randomLightIdx - N_AREA_LIGHTS].ID;
        return DirectSamplePointLight(randomLightIdx - N_AREA_LIGHTS, view_point, num_lights, wiW, pdf);
#endif
    }
    // Chose a spot light
    else if(randomLightIdx < N_AREA_LIGHTS + N_POINT_LIGHTS + N_SPOT_LIGHTS) {
#if N_SPOT_LIGHTS
        chosenLightID = spotLights[randomLightIdx - N_AREA_LIGHTS - N_POINT_LIGHTS].ID;
        return DirectSampleSpotLight(randomLightIdx - N_AREA_LIGHTS - N_POINT_LIGHTS, view_point, num_lights, wiW, pdf);
#endif
    }
    // Chose the environment light
    else {
        chosenLightID = -1;
        // TODO
        vec2 xi = vec2(rng(),rng());
        vec3 wi = squareToHemisphereCosine(xi);
        pdf = squareToHemisphereCosinePDF(wi);
        wi = LocalToWorld(nor) * wi;
        Ray ray = SpawnRay(view_point, normalize(wi));
        wiW = ray.direction;
        Intersection intersection = sceneIntersect(ray);
        if(intersection.t == INFINITY) {
            vec2 uv = sampleSphericalMap(wi);
            return num_lights * texture(u_EnvironmentMap, uv).rgb;
        }
    }
    return vec3(0.);
}

float UniformConePdf(float cosThetaMax) {
    return 1 / (2 * PI * (1 - cosThetaMax));
}

float SpherePdf(Intersection ref, vec3 p, vec3 wi,
                Transform transform, float radius) {
    vec3 nor = ref.nor;
    vec3 pCenter = (transform.T * vec4(0, 0, 0, 1)).xyz;
    // Return uniform PDF if point is inside sphere
    vec3 pOrigin = p + nor * 0.0001;
    // If inside the sphere
    if(DistanceSquared(pOrigin, pCenter) <= radius * radius) {
//        return Shape::Pdf(ref, wi);
        // To be provided later
        return 0.f;
    }

    // Compute general sphere PDF
    float sinThetaMax2 = radius * radius / DistanceSquared(p, pCenter);
    float cosThetaMax = sqrt(max(0.f, 1.f - sinThetaMax2));
    return UniformConePdf(cosThetaMax);
}


float Pdf_Li(vec3 view_point, vec3 nor, vec3 wiW, int chosenLightIdx) {

    Ray ray = SpawnRay(view_point, wiW);

    // Area light
    if(chosenLightIdx < N_AREA_LIGHTS) {
#if N_AREA_LIGHTS
        Intersection isect = areaLightIntersect(areaLights[chosenLightIdx],
                                                ray);
        if(isect.t == INFINITY) {
            return 0.;
        }
        vec3 light_point = ray.origin + isect.t * wiW;
        // If doesn't intersect, 0 PDF
        if(isect.t == INFINITY) {
            return 0.;
        }

        int type = areaLights[chosenLightIdx].shapeType;
        if(type == RECTANGLE) {
            // TODO
            AreaLight light = areaLights[chosenLightIdx];
            vec3 xi = vec3(rng(), rng(), 0);
            xi.x = xi.x * 2. - 1.;
            xi.y = xi.y * 2. - 1.;
            xi = vec3(light.transform.T * vec4(xi, 1));
            vec3 normal = light.transform.invTransT * vec3(0., 0., 1.);
            float area = 4 * light.transform.scale.x * light.transform.scale.y;
            float pdf = float(1.f / area);
            wiW = normalize(xi - view_point);
            Ray ray = SpawnRay(view_point, wiW);
            Intersection intersection = sceneIntersect(ray);
            if (dot(intersection.Le, intersection.Le) <= 0.) {
                return 0;
            }
            if (max(dot(normal, -wiW), 0) == 0.) {
                return 0;
            }
            return pdf * distance(xi, view_point) * distance(xi, view_point) / max(dot(normal, -wiW), 0);
        }
        else if(type == SPHERE) {
            return SpherePdf(isect, light_point, wiW,
                                  areaLights[chosenLightIdx].transform,
                                  1.f);
        }
#endif
    }
    // Point light or spot light
    else if(chosenLightIdx < N_AREA_LIGHTS + N_POINT_LIGHTS ||
            chosenLightIdx < N_AREA_LIGHTS + N_POINT_LIGHTS + N_SPOT_LIGHTS) {
        return 0;
    }
    // Env map
    else {
        // TODO
        return squareToHemisphereCosinePDF(WorldToLocal(nor) * wiW);
    }
}

float PowerHeuristic(int nf, float fPdf, int ng, float gPdf) {
    // TODO
    if (fPdf == 0.f && gPdf == 0.f) {
        return 0.f;
    }
    return (nf * fPdf *  nf * fPdf) / (nf * fPdf *  nf * fPdf + ng * gPdf * ng * gPdf);
}
