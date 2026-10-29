import Foundation
import JavaScriptCore

/// Values that can pass through an expression (AE uses numbers and arrays).
protocol ExpressionValue: Interpolatable {
    var exprComponents: [Double] { get }
    init?(exprComponents: [Double])
}

extension Double: ExpressionValue {
    var exprComponents: [Double] { [self] }
    init?(exprComponents c: [Double]) { guard let v = c.first, v.isFinite else { return nil }; self = v }
}

extension Vec2: ExpressionValue {
    var exprComponents: [Double] { [x, y] }
    init?(exprComponents c: [Double]) {
        guard c.count >= 2, c[0].isFinite, c[1].isFinite else { return nil }
        self.init(c[0], c[1])
    }
}

extension RGBA: ExpressionValue {
    var exprComponents: [Double] { [r, g, b, a] }
    init?(exprComponents c: [Double]) {
        guard c.count >= 3, c.allSatisfy(\.isFinite) else { return nil }
        self.init(c[0], c[1], c[2], c.count > 3 ? c[3] : 1)
    }
}

/// Context an expression sees (AE globals).
struct ExpressionScope {
    var time: Double
    var fps: Double
    var compWidth: Int
    var compHeight: Int
    var compDuration: Double
    var layerIndex: Int
    var layerName: String
    var inPoint: Double
    var outPoint: Double
    /// Stable per-property seed (wiggle/random differ per property, like AE).
    var seed: Double
}

/// AE-compatible expression evaluator on JavaScriptCore (ES2018+, like AE's modern JavaScript engine).
final class ExpressionEngine {
    static let shared = ExpressionEngine()

    private let ctx: JSContext
    private let lock = NSLock()
    private(set) var lastErrors: [String: String] = [:]

    init() {
        ctx = JSContext()!
        let wiggle: @convention(block) (Double, Double, Double, Double, Double, Double) -> Double = { freq, amp, oct, mult, t, seed in
            Wiggle.value(t: t, freq: freq, octaves: max(1, Int(oct)), ampMult: mult, seed: seed) * amp
        }
        ctx.setObject(wiggle, forKeyedSubscript: "__wiggle" as NSString)
        ctx.evaluateScript(Self.prelude)
    }

    func error(for key: String) -> String? { lock.lock(); defer { lock.unlock() }; return lastErrors[key] }

    /// Evaluates `prop.expression` at `scope.time`. Returns nil (and records the error) on failure.
    func evaluate<V: ExpressionValue>(_ prop: Animated<V>, scope: ExpressionScope, key: String) -> V? {
        guard let src = prop.expression else { return nil }
        lock.lock(); defer { lock.unlock() }

        let preValue = prop.value(at: scope.time)
        let valueAt: @convention(block) (Double) -> Any = { t in
            let v = prop.value(at: t).exprComponents
            return v.count == 1 ? v[0] as Any : v as Any
        }
        ctx.setObject(valueAt, forKeyedSubscript: "__valueAt" as NSString)
        ctx.setObject(prop.keyframeTimes, forKeyedSubscript: "__kf" as NSString)
        let comps = preValue.exprComponents
        ctx.setObject(comps.count == 1 ? comps[0] as Any : comps as Any, forKeyedSubscript: "value" as NSString)
        ctx.setObject(scope.time, forKeyedSubscript: "time" as NSString)
        ctx.setObject(scope.seed, forKeyedSubscript: "__seed" as NSString)
        ctx.setObject(scope.fps, forKeyedSubscript: "__fps" as NSString)
        ctx.setObject([
            "width": scope.compWidth, "height": scope.compHeight, "duration": scope.compDuration,
            "frameDuration": 1 / scope.fps, "numLayers": 0,
        ], forKeyedSubscript: "thisComp" as NSString)
        ctx.setObject(["index": scope.layerIndex, "name": scope.layerName, "inPoint": scope.inPoint, "outPoint": scope.outPoint],
                      forKeyedSubscript: "thisLayer" as NSString)
        ctx.setObject(scope.layerIndex, forKeyedSubscript: "index" as NSString)
        ctx.setObject(scope.inPoint, forKeyedSubscript: "inPoint" as NSString)
        ctx.setObject(scope.outPoint, forKeyedSubscript: "outPoint" as NSString)
        ctx.setObject(src, forKeyedSubscript: "__src" as NSString)
        ctx.exception = nil

        let result = ctx.evaluateScript("__run()")
        if let ex = ctx.exception {
            lastErrors[key] = ex.toString() ?? "Expression error"
            ctx.exception = nil
            return nil
        }
        guard let result, !result.isUndefined, !result.isNull else {
            lastErrors[key] = "Expression produced no value"
            return nil
        }
        var comp: [Double]
        if result.isArray, let arr = result.toArray() {
            comp = arr.compactMap { ($0 as? NSNumber)?.doubleValue }
        } else if result.isNumber {
            comp = [result.toDouble()]
        } else if result.isBoolean {
            comp = [result.toBool() ? 1 : 0]
        } else {
            lastErrors[key] = "Expression must return a number or array"
            return nil
        }
        // AE pads missing dimensions from the pre-expression value (e.g. scale returning [x] keeps y).
        if comp.count < comps.count { comp += comps[comp.count...] }
        guard let v = V(exprComponents: comp) else {
            lastErrors[key] = "Expression returned the wrong number of values"
            return nil
        }
        lastErrors[key] = nil
        return v
    }

    /// JS prelude implementing AE's expression API on top of the native hooks.
    static let prelude = #"""
    var __seedOverride = null, __timeless = false, __rng = null, __rngKey = null;
    function __run() {
        // Same frame + same property = same random numbers, like AE: restart the stream every evaluation.
        __rng = null; __rngKey = null; __seedOverride = null; __timeless = false;
        // Fresh scope per evaluation; `eval` returns the value of the last statement, like AE.
        return (function () { return eval(__src); })();
    }
    function __isArr(a) { return Array.isArray(a); }
    function __zip(a, b, f) {
        if (__isArr(a) && __isArr(b)) { var n = Math.max(a.length, b.length), r = []; for (var i = 0; i < n; i++) r.push(f(a[i] || 0, b[i] || 0)); return r; }
        if (__isArr(a)) return a.map(function (x) { return f(x, b); });
        if (__isArr(b)) return b.map(function (x) { return f(a, x); });
        return f(a, b);
    }
    function add(a, b) { return __zip(a, b, function (x, y) { return x + y; }); }
    function sub(a, b) { return __zip(a, b, function (x, y) { return x - y; }); }
    function mul(a, b) { return __zip(a, b, function (x, y) { return x * y; }); }
    function div(a, b) { return __zip(a, b, function (x, y) { return x / y; }); }
    function clamp(v, lo, hi) { return __zip(__zip(v, lo, Math.max), hi, Math.min); }
    function length(a, b) { if (b !== undefined) a = sub(a, b); if (!__isArr(a)) return Math.abs(a); return Math.sqrt(a.reduce(function (s, x) { return s + x * x; }, 0)); }
    function normalize(a) { var l = length(a) || 1; return div(a, l); }
    function dot(a, b) { var s = 0; for (var i = 0; i < a.length; i++) s += a[i] * b[i]; return s; }
    function degreesToRadians(d) { return d * Math.PI / 180; }
    function radiansToDegrees(r) { return r * 180 / Math.PI; }
    function valueAtTime(t) { return __valueAt(t); }
    function velocityAtTime(t) { var h = 0.001; return div(sub(__valueAt(t + h), __valueAt(t - h)), 2 * h); }
    Object.defineProperty(this, "velocity", { get: function () { return velocityAtTime(time); }, configurable: true });
    Object.defineProperty(this, "speed", { get: function () { return length(velocityAtTime(time)); }, configurable: true });
    function posterizeTime(fps) { if (fps > 0) time = Math.floor(time * fps + 1e-6) / fps; }
    function framesToTime(f, fps) { return f / (fps || __fps); }
    function timeToFrames(t, fps) { return Math.round((t === undefined ? time : t) * (fps || __fps)); }

    function wiggle(freq, amp, octaves, amp_mult, t) {
        octaves = octaves || 1; amp_mult = (amp_mult === undefined) ? 0.5 : amp_mult; t = (t === undefined) ? time : t;
        if (__isArr(value)) return value.map(function (v, i) { return v + __wiggle(freq, amp, octaves, amp_mult, t, __seed + i * 101); });
        return value + __wiggle(freq, amp, octaves, amp_mult, t, __seed);
    }
    function temporalWiggle(freq, amp, octaves, amp_mult, t) {
        t = (t === undefined) ? time : t;
        var off = __wiggle(freq, amp, octaves || 1, (amp_mult === undefined) ? 0.5 : amp_mult, t, __seed + 7);
        return valueAtTime(t + off);
    }
    function smooth(width, samples, t) {
        width = width || 0.2; samples = samples || 5; t = (t === undefined) ? time : t;
        var acc = null;
        for (var i = 0; i < samples; i++) { var v = valueAtTime(t - width / 2 + width * i / Math.max(1, samples - 1)); acc = acc === null ? v : add(acc, v); }
        return div(acc, samples);
    }

    function __interp(t, a, b, c, d, f) {
        var tMin, tMax, v1, v2;
        if (c === undefined) { tMin = 0; tMax = 1; v1 = a; v2 = b; } else { tMin = a; tMax = b; v1 = c; v2 = d; }
        var u = tMax === tMin ? (t >= tMax ? 1 : 0) : (t - tMin) / (tMax - tMin);
        u = Math.min(1, Math.max(0, u));
        u = f(u);
        return add(v1, mul(sub(v2, v1), u));
    }
    function linear(t, a, b, c, d) { return __interp(t, a, b, c, d, function (u) { return u; }); }
    function ease(t, a, b, c, d) { return __interp(t, a, b, c, d, function (u) { return u * u * (3 - 2 * u); }); }
    function easeIn(t, a, b, c, d) { return __interp(t, a, b, c, d, function (u) { return u * u; }); }
    function easeOut(t, a, b, c, d) { return __interp(t, a, b, c, d, function (u) { return 1 - (1 - u) * (1 - u); }); }

    function __mulberry(a) { return function () { a |= 0; a = a + 0x6D2B79F5 | 0; var t = Math.imul(a ^ a >>> 15, 1 | a); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; }; }
    function seedRandom(seed, timeless) { __seedOverride = seed; __timeless = !!timeless; __rng = null; }
    function __rand01() {
        var key = (__seedOverride === null ? __seed : __seedOverride * 7919 + __seed) + (__timeless ? 0 : Math.floor(time * __fps + 1e-6) * 104729);
        if (__rng === null || __rngKey !== key) { __rng = __mulberry(Math.floor(key) | 0); __rngKey = key; }
        return __rng();
    }
    function random(a, b) {
        if (a === undefined) return __rand01();
        if (b === undefined) return __zip(a, 0, function (x) { return x * __rand01(); });
        return __zip(a, b, function (x, y) { return x + (y - x) * __rand01(); });
    }
    function gaussRandom(a, b) { var u = 0, v = 0; while (u === 0) u = __rand01(); v = __rand01(); var g = Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * v) / 3 * 0.5 + 0.5; return a === undefined ? g : (b === undefined ? mul(a, g) : add(a, mul(sub(b, a), g))); }
    function noise(x) { var v = __isArr(x) ? x[0] + (x[1] || 0) * 57.1 + (x[2] || 0) * 113.3 : x; return __wiggle(1, 1, 1, 0.5, v, 0); }

    function __loop(type, numKf, out, dur) {
        var k = __kf, n = k.length;
        if (n < 2) return value;
        type = (type || "cycle").toLowerCase();
        var first, last;
        if (dur !== undefined && dur > 0) {
            if (out) { last = k[n - 1]; first = Math.max(k[0], last - dur); } else { first = k[0]; last = Math.min(k[n - 1], first + dur); }
        } else if (out) { last = k[n - 1]; first = numKf > 0 ? k[Math.max(0, n - 1 - numKf)] : k[0]; }
        else { first = k[0]; last = numKf > 0 ? k[Math.min(n - 1, numKf)] : k[n - 1]; }
        var span = last - first;
        if (span <= 0) return value;
        if (out && time <= last) return value;
        if (!out && time >= first) return value;
        var el = out ? time - last : first - time;
        var cycles = Math.floor(el / span), r = el - cycles * span;
        if (type === "cycle") return valueAtTime(out ? first + r : last - r);
        if (type === "pingpong") { var fwd = (cycles % 2 === 0); return out ? valueAtTime(fwd ? last - r : first + r) : valueAtTime(fwd ? first + r : last - r); }
        if (type === "offset") {
            var delta = sub(valueAtTime(last), valueAtTime(first));
            return out ? add(valueAtTime(first + r), mul(delta, cycles + 1)) : sub(valueAtTime(last - r), mul(delta, cycles + 1));
        }
        if (type === "continue") {
            var h = 0.001, edge = out ? last : first;
            var vel = div(sub(valueAtTime(edge + (out ? 0 : h)), valueAtTime(edge - (out ? h : 0))), h);
            return add(valueAtTime(edge), mul(vel, out ? el : -el));
        }
        return value;
    }
    Object.defineProperty(this, "numKeys", { get: function () { return __kf.length; }, configurable: true });
    function key(i) { var t = __kf[i - 1]; return { time: t, value: valueAtTime(t) }; }
    function nearestKey(t) { var best = 0; for (var i = 1; i < __kf.length; i++) if (Math.abs(__kf[i] - t) < Math.abs(__kf[best] - t)) best = i; return key(best + 1); }
    // AWIeffect helper: springy overshoot after the last keyframe (amplitude, bounces per second, decay).
    function inertia(amp, freq, decay) {
        amp = amp === undefined ? 0.05 : amp; freq = freq === undefined ? 2.5 : freq; decay = decay === undefined ? 5 : decay;
        if (__kf.length < 2) return value;
        var last = __kf[__kf.length - 1];
        if (time <= last) return value;
        var el = time - last, v = velocityAtTime(last - 0.001);
        return add(value, mul(v, amp * Math.sin(freq * el * 2 * Math.PI) / Math.exp(decay * el)));
    }
    function loopOut(type, numKf) { return __loop(type, numKf || 0, true); }
    function loopIn(type, numKf) { return __loop(type, numKf || 0, false); }
    function loopOutDuration(type, dur) { return __loop(type, 0, true, dur); }
    function loopInDuration(type, dur) { return __loop(type, 0, false, dur); }
    """#
}

/// Bakes expressions into plain values for one frame, so the renderer never needs to know about them.
enum ExpressionResolver {
    /// Stable across launches (Swift's hashValue is randomized per process).
    static func stableSeed(_ id: UUID, _ salt: String) -> Double {
        var h: UInt64 = 1469598103934665603
        for b in withUnsafeBytes(of: id.uuid, Array.init) + Array(salt.utf8) { h = (h ^ UInt64(b)) &* 1099511628211 }
        return Double(h % 1_000_003)
    }

    static func hasExpressions(_ p: Project) -> Bool {
        p.layers.contains { l in
            let t = l.transform
            if t.position.hasActiveExpression || t.scale.hasActiveExpression || t.rotation.hasActiveExpression
                || t.opacity.hasActiveExpression || t.anchor.hasActiveExpression || l.size.hasActiveExpression
                || l.fill.hasActiveExpression || l.cornerRadius.hasActiveExpression { return true }
            return l.effects.contains { e in e.params.values.contains { v in
                switch v {
                case .number(let a): return a.hasActiveExpression
                case .point(let a): return a.hasActiveExpression
                case .color(let a): return a.hasActiveExpression
                default: return false
                }
            } }
        }
    }

    static func resolve(_ project: Project, time: Double) -> Project {
        guard hasExpressions(project) else { return project }
        var p = project
        let engine = ExpressionEngine.shared
        for i in p.layers.indices {
            let l = p.layers[i]
            func scope(_ salt: String) -> ExpressionScope {
                // Read comp settings from the untouched input: `p` is being mutated through inout while this runs.
                ExpressionScope(time: time, fps: project.fps, compWidth: project.width, compHeight: project.height, compDuration: project.duration,
                                layerIndex: i + 1, layerName: l.name, inPoint: l.inPoint, outPoint: l.outPoint,
                                seed: stableSeed(l.id, salt))
            }
            func bake<V: ExpressionValue>(_ a: inout Animated<V>, _ key: String) {
                guard a.hasActiveExpression else { return }
                if let v = engine.evaluate(a, scope: scope(key), key: "\(l.id)/\(key)") {
                    a.keyframes = []
                    a.staticValue = v
                }
                a.expression = nil
            }
            bake(&p.layers[i].transform.position, "position")
            bake(&p.layers[i].transform.scale, "scale")
            bake(&p.layers[i].transform.rotation, "rotation")
            bake(&p.layers[i].transform.opacity, "opacity")
            bake(&p.layers[i].transform.anchor, "anchor")
            bake(&p.layers[i].size, "size")
            bake(&p.layers[i].fill, "fill")
            bake(&p.layers[i].cornerRadius, "cornerRadius")
            for ei in p.layers[i].effects.indices {
                let eid = p.layers[i].effects[ei].id
                for (k, v) in p.layers[i].effects[ei].params {
                    switch v {
                    case .number(var a): bake(&a, "\(eid)/\(k)"); p.layers[i].effects[ei].params[k] = .number(a)
                    case .point(var a): bake(&a, "\(eid)/\(k)"); p.layers[i].effects[ei].params[k] = .point(a)
                    case .color(var a): bake(&a, "\(eid)/\(k)"); p.layers[i].effects[ei].params[k] = .color(a)
                    default: break
                    }
                }
            }
        }
        return p
    }
}
