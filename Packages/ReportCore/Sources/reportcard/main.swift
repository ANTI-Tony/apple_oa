import Foundation
import ReportCLIKit

do {
    let code = try CLI().run(Array(CommandLine.arguments.dropFirst()))
    exit(code)
} catch {
    FileHandle.standardError.write(Data("error: \(error)\n".utf8))
    exit(2)
}
