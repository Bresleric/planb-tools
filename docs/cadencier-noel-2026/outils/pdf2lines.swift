import Foundation
import PDFKit
// usage: pdf2lines <outdir> <pdf...> : lignes via PDFSelection.selectionsByLine, fusion des segments de meme hauteur
let args = CommandLine.arguments
let outDir = args[1]
for path in args.dropFirst(2) {
    let url = URL(fileURLWithPath: path)
    guard let doc = PDFDocument(url: url) else { print("\(url.lastPathComponent)\tERR"); continue }
    var out = ""
    for pi in 0..<doc.pageCount {
        guard let page = doc.page(at: pi) else { continue }
        let box = page.bounds(for: .mediaBox)
        guard let sel = page.selection(for: box) else { continue }
        struct Seg { var x: CGFloat; var y: CGFloat; var maxX: CGFloat; var s: String }
        var segs: [Seg] = []
        for ls in sel.selectionsByLine() {
            let b = ls.bounds(for: page)
            let s = (ls.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if s.isEmpty { continue }
            segs.append(Seg(x: b.minX, y: b.midY, maxX: b.maxX, s: s))
        }
        segs.sort { $0.y > $1.y + 2.0 || (abs($0.y - $1.y) <= 2.0 && $0.x < $1.x) }
        var lines: [[Seg]] = []
        for sg in segs {
            if let last = lines.last, abs(last[0].y - sg.y) <= 2.0 { lines[lines.count-1].append(sg) }
            else { lines.append([sg]) }
        }
        out += "\n===== PAGE \(pi+1) =====\n"
        for var ln in lines {
            ln.sort { $0.x < $1.x }
            var text = ""; var lastMax: CGFloat = -1
            for sg in ln {
                if lastMax >= 0 {
                    let gap = sg.x - lastMax
                    text += String(repeating: " ", count: max(1, min(Int(gap / 4.5), 60)))
                }
                text += sg.s; lastMax = sg.maxX
            }
            out += text + "\n"
        }
    }
    let dest = URL(fileURLWithPath: outDir).appendingPathComponent(url.deletingPathExtension().lastPathComponent + ".txt")
    try? out.write(to: dest, atomically: true, encoding: .utf8)
    print("\(url.lastPathComponent)\t\(doc.pageCount)p\t\(out.count)c")
}
