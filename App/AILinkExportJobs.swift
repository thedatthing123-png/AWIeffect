import Foundation
import UIKit

/// Remote export jobs use the exact native Exporter as the Export Sheet.
@MainActor
final class AILinkExportJobs {
    static let shared = AILinkExportJobs()

    final class Job {
        let exporter: Exporter
        var state = "running"
        var progress = 0.0
        var output: String?
        var error: String?
        init(exporter: Exporter) { self.exporter = exporter }
    }

    private var jobs: [String: Job] = [:]

    func start(project: Project, settings: ExportSettings, mediaURL: @escaping (String) -> URL) -> [String: Any] {
        // Keep historical status bounded, even if the assistant starts many exports.
        if jobs.count > 100 {
            for id in jobs.keys.sorted() where jobs.count > 80 && jobs[id]?.state != "running" { jobs.removeValue(forKey:id) }
        }
        let id = UUID().uuidString
        let exporter = Exporter()
        let job = Job(exporter: exporter)
        jobs[id] = job
        UIApplication.shared.isIdleTimerDisabled = true
        Task.detached {
            do {
                let url = try await exporter.export(project:project,settings:settings,mediaURL:mediaURL) { p in
                    Task { @MainActor in job.progress = max(0,min(1,p)) }
                }
                let folder = FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0]
                    .appendingPathComponent("AWIeffect-Exports",isDirectory:true)
                try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
                let destination = folder.appendingPathComponent("AWIeffect-\(id).\(settings.format.fileExtension)")
                try FileManager.default.moveItem(at:url,to:destination)
                await MainActor.run {
                    job.state = "completed"
                    job.progress = 1
                    job.output = destination.path
                    UIApplication.shared.isIdleTimerDisabled = false
                }
            } catch {
                await MainActor.run {
                    job.state = "failed"
                    job.error = error.localizedDescription
                    UIApplication.shared.isIdleTimerDisabled = false
                }
            }
        }
        return ["ok":true,"job":id,"state":"running"]
    }

    func status(_ id: String) -> [String: Any]? {
        guard let job=jobs[id] else { return nil }
        var data: [String: Any] = ["job":id,"state":job.state,"progress":job.progress]
        if let file=job.output { data["file"]=file }
        if let error=job.error { data["error"]=error }
        return data
    }

    func cancel(_ id: String) -> [String: Any]? {
        guard let job=jobs[id] else { return nil }
        if job.state == "running" {
            job.exporter.cancel()
            job.state = "cancelling"
        }
        return status(id)
    }
}
