// Native translation of supplied Payload/AlightMotion.app/BuiltinEffects/startunnel.xml
// Original source comments and attribution:
// Star Tunnel - camera pose + auto motion blur (based on @P_Malin)
// AM official style: fixed loops, only builtins
// Tunables (kept as constants for stability)
// Screen ray
// Camera XY offsets: shift screen pos (parallax-like)
// Apply rotations
// Forward motion controlled by zSpeed and camZ offset
// Auto motion-blur -> particle trail length (includes rotation-driven blur)
// deg/s to trail scalar
// in Z units
// No background: start from black for transparent background
// Pass count (1..3 capped)
// Alpha derived from star intensity (transparent background)
#pragma clang diagnostic ignored "-Wmissing-prototypes"

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

// Implementation of the GLSL radians() function
template<typename T>
inline T radians(T d)
{
    return d * T(0.01745329251);
}

struct ReferenceUniformse3db98197ff5f
{
    float4 refScreen;
    float4 refLayer;
    float4 refComposition;
    float4x4 refLayerToScreen;
    float4x4 refScreenToLayer;
    float camX;
    char _m6_pad[12];
    float camY;
    char _m7_pad[12];
    float camZ;
    float3 rotDeg;
    float zSpeed;
    char _m10_pad[12];
    uint autoBlur;
    char _m11_pad[12];
    float blurFactor;
    char _m12_pad[12];
    float rotBlurSpeed;
    char _m13_pad[12];
    float manualTrail;
    char _m14_pad[12];
    float brightness;
    char _m15_pad[12];
    float particleSize;
    char _m16_pad[12];
    float particleCount;
    char _m17_pad[12];
    float alpha;
};

struct refAM35_e3db98197ff5f_out
{
    float4 finalColor [[color(0)]];
};

static inline __attribute__((always_inline))
float3 RotateX(thread const float3& v, thread const float& a)
{
    float s = sin(a);
    float c = cos(a);
    return float3(v.x, (c * v.y) + (s * v.z), ((-s) * v.y) + (c * v.z));
}

static inline __attribute__((always_inline))
float3 RotateY(thread const float3& v, thread const float& a)
{
    float s = sin(a);
    float c = cos(a);
    return float3((c * v.x) + (s * v.z), v.y, ((-s) * v.x) + (c * v.z));
}

static inline __attribute__((always_inline))
float3 RotateZ(thread const float3& v, thread const float& a)
{
    float s = sin(a);
    float c = cos(a);
    return float3((c * v.x) + (s * v.y), ((-s) * v.x) + (c * v.y), v.z);
}

static inline __attribute__((always_inline))
float Random(thread const float& x)
{
    return fract(((sin(x * 123.45600128173828125) * 23.456699371337890625) + (sin(x * 345.678009033203125) * 45.67890167236328125)) + (sin(x * 456.78900146484375) * 56.78900146484375));
}

static inline __attribute__((always_inline))
float3 GetParticlePos(thread const float3& vRayDir, thread const float& fZPos, thread const float& fSeed)
{
    float fAngle = precise::atan2(vRayDir.x, vRayDir.y);
    float fAngleFraction = fract(fAngle / 6.283185482025146484375);
    float fSegment = (floor((fAngleFraction * 121.0) + fSeed) + 0.5) - fSeed;
    float fParticleAngle = (fSegment / 121.0) * 6.283185482025146484375;
    float fSegmentPos = fSegment / 121.0;
    float param = fSegmentPos + fSeed;
    float fRadius = 0.800000011920928955078125 + (Random(param) * 4.19999980926513671875);
    float tunnelZ = vRayDir.z / length(vRayDir.xy / float2(fRadius));
    tunnelZ += fZPos;
    float param_1 = (fSegmentPos + 0.100000001490116119384765625) + fSeed;
    float fRepeat = 1.0 + (Random(param_1) * 1.0);
    float fParticleZ = ((ceil(tunnelZ / fRepeat) - 0.5) * fRepeat) - fZPos;
    return float3(sin(fParticleAngle) * fRadius, cos(fParticleAngle) * fRadius, fParticleZ);
}

static inline __attribute__((always_inline))
float3 GetParticleColour(thread const float3& vParticlePos, thread const float& fParticleSize, thread const float3& vRayDir, thread const float& particleLength, thread const float& brightness)
{
    float2 vNormDir = fast::normalize(vRayDir.xy);
    float d1 = dot(vParticlePos.xy, vNormDir) / fast::max(length(vRayDir.xy), 9.9999997473787516355514526367188e-06);
    float3 vClosest2d = vRayDir * d1;
    float3 vClampedPos = vParticlePos;
    vClampedPos.z = fast::clamp(vClosest2d.z, vParticlePos.z - particleLength, vParticlePos.z + particleLength);
    float d = dot(vClampedPos, vRayDir);
    float3 vClosestPos = vRayDir * d;
    float3 vDeltaPos = vClampedPos - vClosestPos;
    float fClosestDist = length(vDeltaPos) / fast::max(fParticleSize, 9.9999997473787516355514526367188e-06);
    float fShade = fast::clamp(1.0 - fClosestDist, 0.0, 1.0);
    fShade = (fShade * exp2((-d) * 0.800000011920928955078125)) * brightness;
    return float3(fShade);
}

static inline __attribute__((always_inline))
float3 Starfield(thread const float3& vRayDir, thread const float& fZPos, thread const float& fSeed, thread const float& fParticleSize, thread const float& particleLength, thread const float& brightness)
{
    float3 param = vRayDir;
    float param_1 = fZPos;
    float param_2 = fSeed;
    float3 vParticlePos = GetParticlePos(param, param_1, param_2);
    float3 param_3 = vParticlePos;
    float param_4 = fParticleSize;
    float3 param_5 = vRayDir;
    float param_6 = particleLength;
    float param_7 = brightness;
    return GetParticleColour(param_3, param_4, param_5, param_6, param_7);
}

static inline __attribute__((always_inline))
void referenceMain(thread float4& gl_FragCoord, constant ReferenceUniformse3db98197ff5f& _354, thread float4& referenceColor)
{
    float2 vScreenUV = gl_FragCoord.xy / _354.refScreen.xy;
    float2 vScreenPos = (vScreenUV * 2.0) - float2(1.0);
    vScreenPos.x *= (_354.refScreen.x / fast::max(_354.refScreen.y, 1.0));
    vScreenPos += (float2(_354.camX, _354.camY) * 0.20000000298023223876953125);
    float3 vRayDir = fast::normalize(float3(vScreenPos, 1.0));
    float3 rotRad = radians(_354.rotDeg);
    float rx = rotRad.x;
    float ry = rotRad.y;
    float rz = rotRad.z;
    float3 param = vRayDir;
    float param_1 = rx;
    vRayDir = RotateX(param, param_1);
    float3 param_2 = vRayDir;
    float param_3 = ry;
    vRayDir = RotateY(param_2, param_3);
    float3 param_4 = vRayDir;
    float param_5 = rz;
    vRayDir = RotateZ(param_4, param_5);
    float t = _354.refScreen.z;
    float fZPos = _354.camZ + (t * _354.zSpeed);
    float fSpeed = abs(_354.zSpeed);
    float rotComponent = _354.rotBlurSpeed * 0.00200000009499490261077880859375;
    float _456;
    if (_354.autoBlur != 0u)
    {
        _456 = _354.blurFactor * ((fSpeed + rotComponent) + 0.001000000047497451305389404296875);
    }
    else
    {
        _456 = _354.manualTrail;
    }
    float particleLength = _456;
    float3 vResult = float3(0.0);
    int passes = int(fast::clamp(_354.particleCount, 1.0, 3.0));
    float fSeed = 0.0;
    for (int i = 0; i < 3; i++)
    {
        if (i >= passes)
        {
            break;
        }
        float3 param_6 = vRayDir;
        float param_7 = fZPos;
        float param_8 = fSeed;
        float param_9 = _354.particleSize;
        float param_10 = particleLength;
        float param_11 = _354.brightness;
        vResult += Starfield(param_6, param_7, param_8, param_9, param_10, param_11);
        fSeed += 1.2339999675750732421875;
    }
    float3 col = sqrt(vResult);
    float starIntensity = fast::max(fast::max(col.x, col.y), col.z);
    float aOut = fast::clamp(starIntensity, 0.0, 1.0) * _354.alpha;
    referenceColor = float4(col, aOut);
}

fragment refAM35_e3db98197ff5f_out refAM35_e3db98197ff5f(constant ReferenceUniformse3db98197ff5f& _354 [[buffer(0)]], float4 gl_FragCoord [[position]])
{
    refAM35_e3db98197ff5f_out out = {};
    float4 referenceColor = float4(0.0);
    referenceMain(gl_FragCoord, _354, referenceColor);
    bool _556 = any(isnan(referenceColor));
    bool _563;
    if (!_556)
    {
        _563 = any(isinf(referenceColor));
    }
    else
    {
        _563 = _556;
    }
    if (_563)
    {
        referenceColor = float4(0.0);
    }
    referenceColor.w = fast::clamp(referenceColor.w, 0.0, 1.0);
    if (referenceColor.w <= 0.0)
    {
        referenceColor = float4(0.0);
    }
    float4 _577 = referenceColor;
    float3 _583 = fast::clamp(_577.xyz, float3(-65504.0), float3(65504.0));
    referenceColor.x = _583.x;
    referenceColor.y = _583.y;
    referenceColor.z = _583.z;
    out.finalColor = referenceColor;
    return out;
}

