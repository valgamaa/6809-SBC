// PiMac - π by Machin's formula, the same method as PI.CMD on the 6809 SBC
//
//   π/4 = 4·arctan(1/5) − arctan(1/239)
//
// One decimal digit per byte, short division by x² and (2k+1), skipping
// leading zeros, the 1/239 starting value tiled from 0041841, six guard
// digits. No big-number library, so the comparison with the 6809 is fair.
//
// This is deliberately the same method with no tuning for the Mac: one
// thread, no SIMD, no multi-digit words, no faster series. It measures the
// hardware running the 6809's algorithm, not how fast a Mac can compute π.
//
// Build and run (no Xcode project needed):
//   swiftc -O -parse-as-library PiMac.swift -o PiMac
//   ./PiMac

import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - The calculation

enum PiEngine {
    static let guardDigits = 6

    /// Returns π as "3." followed by `digits` decimal places, and the time in seconds.
    static func compute(digits n1: Int) -> (digits: [UInt8], seconds: Double) {
        let n = n1 + guardDigits
        let p = UnsafeMutablePointer<UInt8>.allocate(capacity: n)
        let t = UnsafeMutablePointer<UInt8>.allocate(capacity: n)
        let a = UnsafeMutablePointer<UInt8>.allocate(capacity: n)
        let b = UnsafeMutablePointer<UInt8>.allocate(capacity: n)
        for buf in [p, t, a, b] { buf.initialize(repeating: 0, count: n) }
        defer { for buf in [p, t, a, b] { buf.deallocate() } }

        let start = DispatchTime.now().uptimeNanoseconds

        // arctan(1/5), starting from 1/5 = 0.2
        p[0] = 2
        arctan(p, t, a, n, 25)

        // arctan(1/239), 1/239 = 0.0041841 0041841 ...
        let pattern: [UInt8] = [0, 0, 4, 1, 8, 4, 1]
        for i in 0..<n { p[i] = pattern[i % 7] }
        arctan(p, t, b, n, 57121)

        // π = 4 · (4·arctan(1/5) − arctan(1/239))
        _ = mulSmall(a, n, 4)
        addSub(b, a, n, 0, subtract: true)
        let integerPart = mulSmall(a, n, 4)

        let seconds = Double(DispatchTime.now().uptimeNanoseconds - start) / 1e9
        var result: [UInt8] = [UInt8(integerPart)]
        result.append(contentsOf: UnsafeBufferPointer(start: a, count: n1))
        return (result, seconds)
    }

    /// Sum the series for arctan(1/x) into z. On entry p holds 1/x.
    static func arctan(_ p: UnsafeMutablePointer<UInt8>, _ t: UnsafeMutablePointer<UInt8>,
                       _ z: UnsafeMutablePointer<UInt8>, _ n: Int, _ x2: Int) {
        var m = 0, f = 0
        var subtract = false
        while f < n {
            _ = divide(p, t, n, f, 2 * m + 1)          // t = p / (2m+1)
            addSub(t, z, n, f, subtract: subtract)       // z = z ± t
            f = divide(p, p, n, f, x2)                   // p = p / x², in place
            m += 1
            subtract.toggle()
        }
    }

    /// dst[f..<n] = src[f..<n] / v. Returns the index of the first non-zero quotient digit (n if none).
    static func divide(_ src: UnsafeMutablePointer<UInt8>, _ dst: UnsafeMutablePointer<UInt8>,
                       _ n: Int, _ f: Int, _ v: Int) -> Int {
        var r = 0, f1 = n
        var i = f
        while i < n {
            r = r * 10 + Int(src[i])
            let q = r / v
            r -= q * v
            if q != 0 && f1 == n { f1 = i }
            dst[i] = UInt8(q)
            i += 1
        }
        return f1
    }

    /// dst = dst ± src for digits n-1 down to f, then carry or borrow above f.
    static func addSub(_ src: UnsafeMutablePointer<UInt8>, _ dst: UnsafeMutablePointer<UInt8>,
                       _ n: Int, _ f: Int, subtract: Bool) {
        var e = 0
        var i = n - 1
        while i >= f {
            var d = Int(dst[i]) + (subtract ? -Int(src[i]) : Int(src[i])) + e
            e = 0
            if d < 0 { d += 10; e = -1 } else if d > 9 { d -= 10; e = 1 }
            dst[i] = UInt8(d)
            i -= 1
        }
        i = f - 1
        while e != 0 && i >= 0 {
            var d = Int(dst[i]) + e
            e = 0
            if d < 0 { d += 10; e = -1 } else if d > 9 { d -= 10; e = 1 }
            dst[i] = UInt8(d)
            i -= 1
        }
    }

    /// buf = buf × m in place. Returns the carry out of the top digit.
    static func mulSmall(_ buf: UnsafeMutablePointer<UInt8>, _ n: Int, _ m: Int) -> Int {
        var c = 0
        var i = n - 1
        while i >= 0 {
            let d = Int(buf[i]) * m + c
            c = d / 10
            buf[i] = UInt8(d - c * 10)
            i -= 1
        }
        return c
    }

    /// "3.14159…" with 50 digits per line, later lines indented, as on the 6809.
    static func format(_ d: [UInt8]) -> String {
        var s = "\(d[0])."
        s.reserveCapacity(d.count + d.count / 25 + 8)
        for i in 1..<d.count {
            if i > 1 && (i - 1) % 50 == 0 { s += "\n  " }
            s.append(Character(UnicodeScalar(48 + d[i])))
        }
        return s
    }
}

// MARK: - The window

struct ContentView: View {
    @State private var digitsText = "1000"
    @State private var output = ""
    @State private var status = "Enter a number of digits and press Calculate."
    @State private var busy = false
    @State private var lastDigits = 0
    @State private var lastSeconds = 0.0

    static let maxDigits = 100_000

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Digits:")
                TextField("", text: $digitsText)
                    .frame(width: 90)
                    .onSubmit(calculate)
                Button("Calculate", action: calculate)
                    .keyboardShortcut(.defaultAction)
                    .disabled(busy)
                Button("Save…", action: save)
                    .disabled(busy || output.isEmpty)
                Spacer()
            }
            Text(status)
                .font(.callout)
                .foregroundStyle(.secondary)
            ScrollView {
                Text(output)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .border(Color(nsColor: .separatorColor))
        }
        .padding()
        .frame(minWidth: 560, minHeight: 420)
    }

    func calculate() {
        let trimmed = digitsText.trimmingCharacters(in: .whitespaces)
        guard let n = Int(trimmed), n >= 1, n <= ContentView.maxDigits else {
            status = "Enter a number from 1 to \(ContentView.maxDigits)."
            return
        }
        busy = true
        status = "Calculating \(n) digits…"
        Task { @MainActor in
            let result = await Task.detached(priority: .userInitiated) {
                let r = PiEngine.compute(digits: n)
                return (PiEngine.format(r.digits), r.seconds)
            }.value
            output = result.0
            lastDigits = n
            lastSeconds = result.1
            status = summary(n, result.1)
            busy = false
        }
    }

    /// The Mac's time, set against PI.CMD on the 2 MHz 6809: 140 s measured
    /// for 1,000 digits, scaled by the square of the digit count otherwise.
    func summary(_ n: Int, _ seconds: Double) -> String {
        let sbc = 140.0 * pow(Double(n) / 1000.0, 2)
        let label = n == 1000 ? "measured" : "est."
        let ratio = seconds > 0 ? sbc / seconds : 0
        let times = NumberFormatter.localizedString(from: NSNumber(value: Int(ratio.rounded())), number: .decimal)
        return "\(n) digits in \(duration(seconds)) on this Mac.  "
            + "6809 at 2 MHz (\(label)): \(duration(sbc)), about \(times)× slower."
    }

    func duration(_ s: Double) -> String {
        if s < 1 { return String(format: "%.1f ms", s * 1000) }
        if s < 120 { return String(format: "%.2f s", s) }
        if s < 7200 { return String(format: "%d min %02d s", Int(s) / 60, Int(s) % 60) }
        if s < 172_800 { return String(format: "%.1f h", s / 3600) }
        return String(format: "%.1f days", s / 86400)
    }

    func save() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "pi-\(lastDigits).txt"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let header = "π to \(lastDigits) decimal places by Machin's formula\n"
            + "Calculated in \(duration(lastSeconds)) on this Mac, \(Date().formatted())\n\n"
        do {
            try (header + output + "\n").write(to: url, atomically: true, encoding: .utf8)
            status = "Saved to \(url.lastPathComponent)."
        } catch {
            status = "Could not save: \(error.localizedDescription)"
        }
    }
}

// MARK: - The app

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Needed when built with swiftc rather than as an Xcode app bundle,
        // so the window comes to the front and takes keyboard input.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct PiMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup("π by Machin's Formula") {
            ContentView()
        }
    }
}
