//
//  KoiPond.metal
//  KoiPond
//
//  The water over a koi pond (or a swimming pool), composited over live
//  SwiftUI with layerEffect (see KoiPondEffect.swift). Everything under the
//  water (the floor view, the koi, their shadows) is one layer, and this
//  bends it the way a rippling surface would:
//
//    • Height: rings spreading from every splash, tap and gulp; over each
//      koi a soft swell, and behind it the swirls its tail sheds; behind a
//      float that's moving, a V-shaped wake. So the surface answers the
//      fish. A faint breeze keeps it alive at rest.
//    • Refraction: the floor is seen through the surface's slope.
//    • Light: sunlight focused by the ripples dances on the floor
//      (caustics: dappled in the pond, the bright net of a pool), the water
//      tints with depth, and the sun glints off the crests.
//
//  Uniforms (points, seconds):
//    size      — layer size
//    clock     — x: time, y: pool mix (0 pond … 1 pool), z, w: unused
//    ripples   — 4 floats each: x, y, age (s), strength (negative: a small,
//                quick-fading tail swirl rather than a full ring)
//    movers    — 4 floats each: x, y, heading (rad), speed 0…1 (negative: a
//                swimmer under the surface, which lifts a swell but leaves no V)
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

constant float kRingSpeed = 72.0;        // pt/s a ripple spreads
constant float kRingWidth = 20.0;        // pt: how deep a ring's band of crests is
constant float kWaveNumber = 0.42;       // rad/pt: about 15 pt between crests
constant float kRippleLife = 3.2;        // s

static inline float kpSq(float x) { return x * x; }

// ── The surface ─────────────────────────────────────────────

/// A breeze: a few long, slow swells crossing at angles.
static float kpBreeze(float2 p, float t, thread float2 &grad) {
    const float2 d1 = normalize(float2(0.8, 0.6)), d2 = normalize(float2(-0.5, 0.9)), d3 = normalize(float2(0.95, -0.3));
    const float k1 = 0.045, k2 = 0.071, k3 = 0.11;
    float a1 = dot(p, d1) * k1 + t * 0.9;
    float a2 = dot(p, d2) * k2 - t * 1.3;
    float a3 = dot(p, d3) * k3 + t * 1.7;
    grad += d1 * k1 * cos(a1) * 0.55 + d2 * k2 * cos(a2) * 0.35 + d3 * k3 * cos(a3) * 0.2;
    return sin(a1) * 0.55 + sin(a2) * 0.35 + sin(a3) * 0.2;
}

/// Spreading rings: each a band of crests riding outward from where it
/// started, fading as it goes and as it ages. Tail swirls (negative
/// strength) are small, slow and gone within a second, and their slope goes
/// to `swirlGrad` so it can light the water more than it bends it.
static float kpRings(float2 p, float t, device const float *ripples, int count,
                     thread float2 &grad, thread float2 &swirlGrad) {
    float h = 0.0;
    for (int i = 0; i + 3 < count; i += 4) {
        float age = ripples[i + 2];
        float strength = ripples[i + 3];
        bool swirl = strength < 0.0;
        strength = abs(strength);
        float speed = swirl ? 44.0 : kRingSpeed;
        float width = swirl ? 8.0 : kRingWidth;
        float k = swirl ? 0.5 : kWaveNumber;   // a swirl is one soft crest
        if (age < 0.0 || age > (swirl ? 1.3 : kRippleLife)) continue;
        float2 d = p - float2(ripples[i], ripples[i + 1]);
        float r = length(d) + 1e-3;
        float x = r - age * speed;
        if (abs(x) > width * 3.0) continue;
        // A ring is weak right where it starts: at its own centre every
        // direction is "outward", and full strength there would twist
        // whatever sits on it (a koi's head as it gulps) into a swirl.
        float env = exp(-kpSq(x / width)) * exp(-age * (swirl ? 2.2 : 0.95)) * strength
                  / (1.0 + r * (swirl ? 0.03 : 0.012)) * smoothstep(0.0, width, r);
        float ph = x * k;
        h += env * sin(ph);
        float2 g = (d / r) * env * k * cos(ph);
        if (swirl) { swirlGrad += g; } else { grad += g; }
    }
    return h;
}

/// Movers. A koi under the surface lifts a soft, long swell that rides over
/// it, a little ahead (its tail swirls come from the world as rings). A
/// floater on the surface also opens a V of crests behind it, longer and
/// stronger the faster it goes.
static float kpWakes(float2 p, float t, device const float *movers, int count) {
    float h = 0.0;
    for (int i = 0; i + 3 < count; i += 4) {
        float speed = movers[i + 3];
        bool under = speed < 0.0;
        speed = abs(speed);
        if (speed <= 0.001) continue;
        float2 rel = p - float2(movers[i], movers[i + 1]);
        float dist2 = dot(rel, rel);
        if (dist2 > 330.0 * 330.0) continue;
        float2 f = float2(cos(movers[i + 2]), sin(movers[i + 2]));
        float2 n = float2(-f.y, f.x);
        float behind = -dot(rel, f);
        float side = abs(dot(rel, n));
        if (under) {
            float ahead = -behind - 6.0;
            h += exp(-(kpSq(ahead / 38.0) + kpSq(side / 20.0))) * 0.5 * speed;
            continue;
        }
        // The swell over the floater.
        h += exp(-dist2 / (26.0 * 26.0)) * 0.45 * speed;
        // The wake: crests along the two arms of a ~20° V.
        if (behind > 0.0) {
            float arm = side - behind * 0.36;
            float inV = exp(-kpSq(arm / (8.0 + behind * 0.11)));
            float fade = exp(-behind / (90.0 + 140.0 * speed)) * smoothstep(0.0, 12.0, behind)
                       * (1.0 - smoothstep(220.0, 320.0, behind));
            h += sin(behind * 0.33 + side * 0.25 - t * 7.0) * inV * fade * 1.9 * speed;
        }
    }
    return h;
}

static float kpWakesGrad(float2 p, float t, device const float *movers, int count, thread float2 &grad) {
    const float e = 1.5;
    float h = kpWakes(p, t, movers, count);
    grad += float2(kpWakes(p + float2(e, 0), t, movers, count) - h,
                   kpWakes(p + float2(0, e), t, movers, count) - h) / e;
    return h;
}

// ── Light under the water ───────────────────────────────────

/// The bright net that rippled water focuses onto a floor.
static float kpCaustic(float2 uv, float t) {
    float2 p = fmod(uv * 6.2831853, 6.2831853) - 250.0;
    float2 i = p;
    float c = 1.0;
    const float inten = 0.005;
    for (int n = 0; n < 5; n++) {
        float tt = t * (1.0 - (3.5 / float(n + 1)));
        i = p + float2(cos(tt - i.x) + sin(tt + i.y), sin(tt - i.y) + cos(tt + i.x));
        c += 1.0 / length(float2(p.x / (sin(i.x + tt) / inten), p.y / (cos(i.y + tt) / inten)));
    }
    c /= 5.0;
    c = 1.17 - pow(c, 1.4);
    return pow(abs(c), 8.0);
}

// ── The effect ──────────────────────────────────────────────

[[ stitchable ]] half4 koiWater(float2 position, SwiftUI::Layer layer,
                                float2 size, float4 clock,
                                device const float *ripples, int rippleCount,
                                device const float *movers, int moverCount) {
    float t = clock.x;
    float pool = clock.y;

    // The surface's slope here.
    float2 grad = float2(0.0);
    float breeze = kpBreeze(position, t, grad);
    grad *= mix(0.35, 0.22, pool);
    float2 ringGrad = float2(0.0), swirlGrad = float2(0.0);
    float h = kpRings(position, t, ripples, rippleCount, ringGrad, swirlGrad);
    float2 wakeGrad = float2(0.0);
    h += kpWakesGrad(position, t, movers, moverCount, wakeGrad);
    // Rings bend the floor as they pass. Tail swirls and wakes mostly catch
    // the light: bent as hard, they'd twist the fish swimming through them.
    float2 bend = grad + ringGrad * 2.6 + swirlGrad * 0.6 + wakeGrad * 0.7;
    grad += ringGrad * 2.6 + swirlGrad * 2.8 + wakeGrad * 1.7;
    h += breeze * 0.3;

    // Refraction: the floor seen through the slope. A pool is clearer and
    // its floor nearer; a pond is deeper.
    float depth = mix(10.0, 11.0, pool);
    // Saturates softly within maxSampleOffset: a hard clamp, hit where many
    // rings pile up, tears whatever is under them into spikes.
    float2 offset = 30.0 * tanh(-bend * depth / 30.0);
    float2 lo = float2(0.5), hi = size - 0.5;
    half3 floorColour = layer.sample(clamp(position + offset, lo, hi)).rgb;
    float3 col = float3(floorColour);

    // Caustics: focused light dancing on the floor, pushed about by the
    // ripples. Dappled in a pond, a bright net in a pool.
    float2 cuv = position / mix(210.0, 150.0, pool) + grad * 0.06;
    float c = kpCaustic(cuv, t * mix(0.45, 0.6, pool));
    float c2 = kpCaustic(cuv * 1.37 + 17.0, t * 0.5);
    float caustic = mix(c * 0.6 + c2 * 0.25, c + c2 * 0.35, pool);

    // A pond: the floor reads through clear blue water. The fish keep their
    // colours: the tint and the murk give way to anything lighter than the
    // floor, or warm (orange, red, gold) where the floor is cool.
    float lum = dot(col, float3(0.299, 0.587, 0.114));
    float clear = max(smoothstep(0.35, 0.75, lum), smoothstep(0.0, 0.18, col.r - col.b));
    // A black koi is dark and neutral where the floor's darks are blue.
    clear = max(clear, smoothstep(0.08, 0.02, col.b - col.r) * smoothstep(0.2, 0.1, lum));
    float3 pondTint = mix(float3(0.80, 0.91, 1.00), float3(1.0), clear);
    float3 pondMurk = float3(0.00, 0.05, 0.12) * (1.0 - clear);
    float3 pondLight = float3(0.80, 0.94, 1.00);
    float3 pondCol = col * pondTint + pondMurk + caustic * pondLight * 0.34 * (0.35 + 0.65 * col);

    float3 poolTint = float3(0.78, 0.95, 1.00);
    float3 poolDeep = float3(0.00, 0.06, 0.10);
    float3 poolLight = float3(0.90, 1.00, 1.00);
    float3 poolCol = col * poolTint + poolDeep + caustic * poolLight * 0.42;

    col = mix(pondCol, poolCol, pool);

    // The banks shade a pond's edges; a pool's walls darken a little.
    float2 toEdge = min(position, size - position);
    float edge = min(toEdge.x, toEdge.y);
    float bank = 1.0 - smoothstep(0.0, mix(70.0, 26.0, pool), edge);
    col *= 1.0 - bank * mix(0.42, 0.18, pool);

    // Slopes facing the sun catch more of it, and every slope mirrors a
    // little more sky, so rings read as bright bands on dark water.
    float2 sunward = normalize(float2(-0.55, -0.8));
    col *= 1.0 + clamp(dot(grad, sunward), -1.5, 1.5) * mix(0.26, 0.14, pool);
    float sheen = saturate(length(grad) * 0.35);
    col = mix(col, mix(float3(0.72, 0.85, 0.98), float3(0.92, 0.98, 1.0), pool), sheen * mix(0.38, 0.18, pool));

    // The surface itself: a little sky, and sun glints on the crests.
    float3 nrm = normalize(float3(-grad * 1.2, 1.0));
    float fresnel = 0.03 + 0.5 * pow(max(1.0 - nrm.z, 0.0), 1.5);
    float3 sky = mix(float3(0.70, 0.85, 0.98), float3(0.86, 0.96, 1.0), pool);
    col = mix(col, sky, saturate(fresnel));
    float3 sun = normalize(float3(-0.45, -0.65, 0.62));
    float3 halfVec = normalize(sun + float3(0.0, 0.0, 1.0));
    float glint = pow(saturate(dot(nrm, halfVec)), mix(150.0, 170.0, pool));
    col += glint * mix(0.9, 1.1, pool) * float3(1.0, 0.99, 0.94);
    // Crests catch a touch more light than troughs.
    col *= 1.0 + h * 0.025;

    return half4(half3(saturate(col)), 1.0);
}
