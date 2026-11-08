import Foundation
import UIKit

/// Remote exports reuse the app's existing Exporter. A job starts immediately and is polled,
/// so long renders do not keep an MCP/WebSocket request open for minutes.
@MainActor
final class AILinkExportJobs {
    static let shared = AILinkExportJobs()
    private var exporter: Exporter?
    private var task: Task<Void, Never>?
    private var jobID: String?
    private var stage = "idle"
    private var progress = 0.0
    private var resultPath: String?
    private var lastError: String?

    func handle(_ request: HTTPRequest, editor e: EditorState) -> HTTPResponse? {
        guard request.path.hasPrefix("/export/") else { return nil }
        let a = ((try? JSONSerialization.jsonObject(with: request.body)) as? [String: Any]) ?? [:]
        switch (request.method, request.path) {
        case ("POST", "/export/start"):
            guard task == nil, UIApplication.shared.applicationState != .background else {
                return .json(["error": "another export is running or app is in the background"], status: 409)
            }
            var settings = ExportSettings()
            if let format = a["format"] as? String {
                guard let value = ExportFormat(rawValue: format) else {
                    return .json(["error": "format must be MP4, MOV (alpha), or GIF"], status: 400)
                }
                settings.format = value
            }
            if let codec = a["codec"] as? String {
                guard let value = VideoCodec(rawValue: codec) else {
                    return .json(["error": "codec must be H.264 or HEVC"], status: 400)
                }
                settings.codec = value
            }
            if let scale = (a["scale"] as? NSNumber)?.doubleValue {
                guard scale.isFinite, scale >= 0.1, scale <= 2 else {
                    return .json(["error": "scale must be 0.1...2"], status: 400)
                }
                settings.scale = scale
            }
            if let fps = (a["fps"] as? NSNumber)?.doubleValue {
                guard fps.isFinite, fps >= 1, fps <= 120 else {
                    return .json(["error": "fps must be 1...120"], status: 400)
                }
                settings.fps = fps
            }
            if let bitrate = (a["bitrateMbps"] as? NSNumber)?.doubleValue {
                guard bitrate.isFinite, bitrate >= 0.5, bitrate <= 250 else {
                    return .json(["error": "bitrateMbps must be 0.5...250"], status: 400)
                }
                settings.bitrateMbps = bitrate
            }
            if let start = (a["start"] as? NSNumber)?.doubleValue {
                guard start.isFinite, start >= 0, start < e.project.duration else {
                    return .json(["error": "start is outside the composition"], status: 400)
                }
                settings.start = start
            }
            if let end = (a["end"] as? NSNumber)?.doubleValue {
                guard end.isFinite, end > settings.start, end <= e.project.duration else {
                    return .json(["error": "end must be within composition and after start"], status: 400)
                }
                settings.end = end
            }
            let job = UUID().uuidString
            jobID = job; stage = "rendering"; progress = 0; resultPath = nil; lastError = nil
            let exp = Exporter()
            exporter = exp
            let project = e.rootProject
            let pid = project.id
            let store = e.store
            task = Task { @MainActor [weak self] in
                guard let self else { return }
                do {
                    let url = try await exp.export(project: project, settings: settings,
                                                   mediaURL: { store.mediaURL($0, projectID: pid) }) { p in
                        Task { @MainActor in self.progress = min(1, max(0, p)) }
                    }
                    let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                        .appendingPathComponent("AWIeffect-Exports", isDirectory: true)
                    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                    let destination = folder.appendingPathComponent("AWI-\(job).\(url.pathExtension)")
                    try FileManager.default.copyItem(at: url, to: destination)
                    self.resultPath = destination.path
                    self.progress = 1
                    self.stage = "completed"
                } catch {
                    self.lastError = String(describing: error)
                    self.stage = "failed"
                }
                self.exporter = nil
                self.task = nil
            }
            return .json(["ok": true, "job": job, "status": "rendering"])
        case ("POST", "/export/status"):
            guard let id = a["job"] as? String, id == jobID else {
                return .json(["error": "unknown export job"], status: 404)
            }
            var response: [String: Any] = ["job": id, "status": stage, "progress": progress]
            if let resultPath { response["fileInAppDocuments"] = resultPath }
            if let lastError { response["error"] = lastError }
            return .json(response)
        case ("POST", "/export/cancel"):
            guard let id = a["job"] as? String, id == jobID, task != nil else {
                return .json(["error": "no running export with this ID"], status: 404)
            }
            exporter?.cancel()
            return .json(["ok": true, "status": "cancel-requested"])
        default:
            return .json(["error": "unknown export endpoint"], status: 404)
        }
    }
}
