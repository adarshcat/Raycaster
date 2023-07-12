#[compute]
#version 460

#define PI 3.1415926

layout(local_size_x = 4, local_size_y = 4, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict buffer DataBuffer {
    float data[];
}
wallData;

layout(set = 0, binding = 1, std430) restrict buffer WorldDataBuffer {
    float playerx;
    float playery;
    float dirx;
    float diry;
    float fov;
}
worldData;

layout(set = 0, binding = 2, std430) restrict buffer OutputBuffer {
    float oData[];
}
outputData;

layout(rgba8, binding = 3) restrict uniform image2D outputImage;

vec2 getIntersection(vec4 l1, vec4 l2){
    float uA = ((l2.z-l2.x)*(l1.y-l2.y) - (l2.w-l2.y)*(l1.x-l2.x)) / ((l2.w-l2.y)*(l1.z-l1.x) - (l2.z-l2.x)*(l1.w-l1.y));
    float uB = ((l1.z-l1.x)*(l1.y-l2.y) - (l1.w-l1.y)*(l1.x-l2.x)) / ((l2.w-l2.y)*(l1.z-l1.x) - (l2.z-l2.x)*(l1.w-l1.y));

    if (uA >= 0.0 && uA <= 1.0 && uB >= 0.0 && uB <= 1.0) {
        float intersectionX = l1.x + (uA * (l1.z-l1.x));
        float intersectionY = l1.y + (uA * (l1.w-l1.y));

        return vec2(intersectionX, intersectionY);
    }

    return vec2(-66666.0, -66666.0);
}

vec2 rotateVec2(vec2 vec, float ang){
    mat2 rotMat = mat2(vec2(cos(ang), sin(ang)), vec2(-sin(ang), cos(ang)));
    return rotMat * vec;
}

float getDir(vec2 vec){
    vec2 norm = normalize(vec);
    return acos(norm.x);
}

void main() {
    const vec2 texSize = gl_WorkGroupSize.xy * gl_NumWorkGroups.xy;
    const ivec2 coord = ivec2(gl_GlobalInvocationID.xy);

    vec2 pos = vec2(worldData.playerx, worldData.playery);
    vec2 dir = rotateVec2(vec2(worldData.dirx, worldData.diry), (float(gl_GlobalInvocationID.x)/texSize.x - 0.5) * worldData.fov);
    vec2 endPoint = pos + dir * 1000000.0;

    vec4 ray = vec4(pos.xy, endPoint.xy);
    float brightness = 0.0;

    for (int i=0; i<wallData.data.length(); i+=4){
        vec4 wall = vec4(wallData.data[i], wallData.data[i+1], wallData.data[i+2], wallData.data[i+3]);

        vec2 iData = getIntersection(ray, wall);

        if (iData.x != -66666.0){
            outputData.oData[0] = iData.x;
            outputData.oData[1] = iData.y;

            float dirDiff = getDir(dir) - getDir(vec2(worldData.dirx, worldData.diry));
            float dist = distance(pos, iData) * cos(dirDiff);
            float hei = texSize.y/dist * 100.0;

            float centre = coord.y - texSize.y/2;

            if (centre < hei/2 && centre > -hei/2){
                brightness = min(1.0/dist * 150.0, 1.0);
            }
        }
    }


    imageStore(outputImage, coord, vec4(brightness, brightness, brightness, 1.0));
}