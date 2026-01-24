import SwiftUI

struct Line {
    var points: [CGPoint]
    var color: Color
    var lineWidth: CGFloat
}

struct SketchComposerView: View {
    @EnvironmentObject var appState: AppState
    let isLocked: Bool
    
    @State private var lines: [Line] = []
    @State private var currentLine = Line(points: [], color: .cyan, lineWidth: 5)
    @State private var selectedColor: Color = .cyan
    
    let colors: [Color] = [.cyan, .pink, .green, .yellow, .white]
    
    var body: some View {
        VStack(spacing: 24) {
            // Canvas
            ZStack {
                Color.black
                    .cornerRadius(24)
                
                Canvas { context, size in
                    for line in lines {
                        var path = Path()
                        path.addLines(line.points)
                        context.stroke(path, with: .color(line.color), lineWidth: line.lineWidth)
                    }
                    
                    var path = Path()
                    path.addLines(currentLine.points)
                    context.stroke(path, with: .color(currentLine.color), lineWidth: currentLine.lineWidth)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let newPoint = value.location
                            currentLine.points.append(newPoint)
                        }
                        .onEnded { _ in
                            lines.append(currentLine)
                            currentLine = Line(points: [], color: selectedColor, lineWidth: 5)
                        }
                )
            }
            .frame(height: 400)
            .padding(.horizontal)
            .overlay(alignment: .topTrailing) {
                Button {
                    lines = []
                } label: {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                        .font(.title)
                        .foregroundColor(.white.opacity(0.5))
                        .padding(24)
                }
            }
            
            // Tool Palette
            HStack(spacing: 20) {
                ForEach(colors, id: \.self) { color in
                    Button {
                        selectedColor = color
                        currentLine.color = color
                    } label: {
                        Circle()
                            .fill(color)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: selectedColor == color ? 3 : 0)
                            )
                            .shadow(color: color.opacity(0.5), radius: 5)
                    }
                }
            }
            
            Spacer()
            
            // Share Button
            Button {
                Task {
                    await shareSketch()
                }
            } label: {
                Text("Send Doodle 🎨")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(selectedColor)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            .disabled(lines.isEmpty)
            .opacity(lines.isEmpty ? 0.5 : 1.0)
        }
        .padding(.top, 16)
    }
    
    private func shareSketch() async {
        // In a real app, convert lines to JSON or render to image
        // For the MVP, we'll just simulate a successful upload
        do {
            try await appState.createVibe(
                type: .sketch,
                isLocked: isLocked
            )
            appState.dismissComposer()
        } catch {
            print("Error sharing sketch: \(error)")
        }
    }
}
