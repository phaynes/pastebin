import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var scanner: ScannerModel

    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                CameraPreview(session: scanner.session)

                ScanFrame()
                    .stroke(scanner.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    .frame(width: 290, height: 290)
                    .shadow(color: scanner.accentColor.opacity(0.45), radius: 18)
                    .animation(.easeInOut(duration: 0.2), value: scanner.statusTitle)
            }
            .background(Color.black)
            .frame(minWidth: 500)

            Divider()
                .overlay(Color.white.opacity(0.08))

            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Image(systemName: scanner.statusSymbol)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(scanner.accentColor)

                        Text(scanner.statusTitle)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.primary)
                    }

                    Text(scanner.statusDetail)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Text(scanner.resultHeading)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Text(scanner.resultText)
                        .font(.system(size: 15, weight: .regular, design: .monospaced))
                        .foregroundStyle(scanner.hasResult ? .primary : .secondary)
                        .lineLimit(8)
                        .textSelection(.enabled)
                        .padding(14)
                        .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                HStack(spacing: 10) {
                    Button {
                        scanner.copyResult()
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    .disabled(!scanner.hasResult)

                    Button {
                        scanner.openURL()
                    } label: {
                        Label("Open", systemImage: "safari")
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(scanner.detectedURL == nil)
                }

                Spacer()

                Button {
                    scanner.reset()
                } label: {
                    Label("Scan Again", systemImage: "viewfinder")
                }
                .disabled(!scanner.hasResult)
            }
            .padding(28)
            .frame(width: 300)
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }
}

private struct ScanFrame: Shape {
    func path(in rect: CGRect) -> Path {
        let cornerLength = min(rect.width, rect.height) * 0.22
        var path = Path()

        path.move(to: CGPoint(x: rect.minX, y: rect.minY + cornerLength))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + cornerLength, y: rect.minY))

        path.move(to: CGPoint(x: rect.maxX - cornerLength, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cornerLength))

        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerLength))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - cornerLength, y: rect.maxY))

        path.move(to: CGPoint(x: rect.minX + cornerLength, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cornerLength))

        return path
    }
}

