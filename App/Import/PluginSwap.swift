import Foundation

/// Popular third-party AE plugins (as stored in .aep files by match name) mapped onto this app's built-in effects,
/// so imported edits keep their look without the plugin. Settings are approximated from typical edit values.
enum PluginSwap {
    struct Sub { let plugin: String; let id: String; var params: [String: ParamValue] = [:] }

    private static func n(_ v: Double) -> ParamValue { .number(Animated(v)) }

    /// Match-name prefix → substitute (checked in order; first prefix match wins).
    static let table: [(String, Sub)] = [
        ("Videocopilot Twitch", Sub(plugin: "Twitch", id: "awi.jitter", params: ["rate": n(24), "amount": n(18), "rotation": n(3)])),
        ("VIDEOCOPILOT OpticalFlares", Sub(plugin: "Optical Flares", id: "ae.lensFlare")),
        ("VIDEOCOPILOT Saber", Sub(plugin: "Saber", id: "awi.saber")),
        ("Keylight", Sub(plugin: "Keylight", id: "awi.chromaKey")),
        ("ADBE Linear Color Key", Sub(plugin: "Linear Color Key", id: "awi.chromaKey")),
        ("ADBE Lumetri", Sub(plugin: "Lumetri Color", id: "awi.looks")),
        ("MB LookSuite", Sub(plugin: "Magic Bullet Looks", id: "awi.looks")),
        ("CS Color Neutralizer", Sub(plugin: "Color Neutralizer", id: "awi.looks")),
        ("FC NITRATE", Sub(plugin: "FilmConvert Nitrate", id: "awi13.warmPortrait")),
        ("BCC3Directional Blur", Sub(plugin: "BCC Directional Blur", id: "ae.directionalBlur")),
        ("BCC Fast Lens Blur", Sub(plugin: "BCC Lens Blur", id: "awi.lensBlur")),
        ("BCC3Film Damage", Sub(plugin: "BCC Film Damage", id: "awi.oldFilm")),
        ("BCC3Unsharp Mask", Sub(plugin: "BCC Unsharp Mask", id: "ae.unsharpMask")),
        ("BCC Cross Glitch", Sub(plugin: "BCC Cross Glitch", id: "awi.glitch")),
        ("BCC3Hue-Sat-Lightness", Sub(plugin: "BCC Hue/Sat/Lightness", id: "ae.hueSaturation")),
        ("BCC_HIGHCONTRAST", Sub(plugin: "BCC High Contrast", id: "ae.brightnessContrast", params: ["contrast": n(45)])),
        ("BCC3Page Turn", Sub(plugin: "BCC Page Turn", id: "awi14.pageCurl")),
        ("S_BlurMoCurves", Sub(plugin: "Sapphire BlurMoCurves", id: "ae.directionalBlur", params: ["length": n(30)])),
        ("S_DropShadow", Sub(plugin: "Sapphire DropShadow", id: "ae.dropShadow")),
        ("S_Vignette", Sub(plugin: "Sapphire Vignette", id: "awi.vignette")),
        ("CS Vignette", Sub(plugin: "Vignette", id: "awi.vignette")),
        ("S_Sharpen", Sub(plugin: "Sapphire Sharpen", id: "ae.sharpen")),
        ("S_EdgeDetect", Sub(plugin: "Sapphire EdgeDetect", id: "ae.findEdges")),
        ("S_ZGlow", Sub(plugin: "Sapphire ZGlow", id: "awi.deepGlow")),
        ("S_Glow", Sub(plugin: "Sapphire Glow", id: "awi.deepGlow")),
        ("S_Cartoon", Sub(plugin: "Sapphire Cartoon", id: "awi8.celShading")),
        ("S_Invert", Sub(plugin: "Sapphire Invert", id: "ae.invert")),
        ("S_Shake", Sub(plugin: "Sapphire Shake", id: "awi.shake")),
        ("S_RackDefocus", Sub(plugin: "Sapphire Rack Defocus", id: "awi.lensBlur")),
        ("S_Flicker", Sub(plugin: "Sapphire Flicker", id: "awi.flicker")),
        ("S_Rays", Sub(plugin: "Sapphire Rays", id: "awi.godRays")),
        ("S_LensFlare", Sub(plugin: "Sapphire LensFlare", id: "ae.lensFlare")),
        ("S_Shine", Sub(plugin: "Sapphire Shine", id: "awi.godRays")),
        ("S_HueSatBright", Sub(plugin: "Sapphire HueSatBright", id: "ae.hueSaturation")),
        ("Universe_Stylize_VHS", Sub(plugin: "Universe VHS", id: "awi.vhs")),
        ("Universe_Generators_Gradient", Sub(plugin: "Universe Gradient", id: "ae.gradientRamp")),
        ("Universe_Glitch", Sub(plugin: "Universe Glitch", id: "awi.glitch")),
        ("Universe_Utilities_Unmult", Sub(plugin: "Universe Unmult", id: "ae.lumaKey")),
        ("APC Shatter", Sub(plugin: "Shatter", id: "awi6.shatter")),
        ("CC Particle World", Sub(plugin: "CC Particle World", id: "awi.particles")),
        ("CC Toner", Sub(plugin: "CC Toner", id: "ae.tritone")),
        ("CC Jaws", Sub(plugin: "CC Jaws", id: "awi9.stripesWipe")),
        ("CS CrossBlur", Sub(plugin: "Cross Blur", id: "ae.gaussianBlur")),
        ("ADBE Minimax", Sub(plugin: "Minimax", id: "awi15.minimax")),
        ("ADBE Color Balance (HLS)", Sub(plugin: "Color Balance (HLS)", id: "ae.hueSaturation")),
        ("ADBE CM WigglePosition", Sub(plugin: "Wiggle Position", id: "awi.shake", params: ["rotation": n(0)])),
        ("Deep Glow", Sub(plugin: "Deep Glow", id: "awi.deepGlow")),
        ("pi_DeepGlow", Sub(plugin: "Deep Glow", id: "awi.deepGlow")),
        ("RSMB", Sub(plugin: "ReelSmart Motion Blur", id: "ae.directionalBlur", params: ["length": n(20)])),
        ("tc Particular", Sub(plugin: "Trapcode Particular", id: "awi.particles")),
        ("tc Shine", Sub(plugin: "Trapcode Shine", id: "awi.godRays")),
        ("tc Starglow", Sub(plugin: "Trapcode Starglow", id: "awi15.starglow")),
    ]

    static func lookup(_ matchName: String) -> Sub? {
        table.first { matchName.hasPrefix($0.0) }?.1
    }
}
