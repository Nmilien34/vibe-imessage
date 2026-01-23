
import SwiftUI

struct PollOptionRow: View {
    @Binding var text: String
    let index: Int
    let showRemove: Bool
    let onRemove: () -> Void
    
    var body: some View {
        HStack {
            TextField("Option \(index + 1)", text: $text)
                .textFieldStyle(.roundedBorder)
            
            if showRemove {
                Button(action: onRemove) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.red)
                }
            }
        }
    }
}
