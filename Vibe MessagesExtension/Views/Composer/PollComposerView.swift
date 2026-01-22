//
//  PollComposerView.swift
//  Vibe MessagesExtension
//
//  Created on 1/22/26.
//

import SwiftUI

struct PollComposerView: View {
    @EnvironmentObject var appState: AppState
    let isLocked: Bool
    
    @State private var question = ""
    @State private var options = ["", ""]
    @FocusState private var focusedField: Int?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Question
                VStack(alignment: .leading) {
                    Text("Question")
                        .font(.headline)
                    TextField("Ask something...", text: $question)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: -1)
                }
                
                // Options
                VStack(alignment: .leading, spacing: 16) {
                    Text("Options")
                        .font(.headline)
                    
                    ForEach(0..<options.count, id: \.self) { index in
                        HStack {
                            TextField("Option \(index + 1)", text: $options[index])
                                .textFieldStyle(.roundedBorder)
                                .focused($focusedField, equals: index)
                            
                            if options.count > 2 {
                                Button {
                                    withAnimation {
                                        options.remove(at: index)
                                    }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                    
                    if options.count < 4 {
                        Button {
                            withAnimation {
                                options.append("")
                            }
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Option")
                            }
                        }
                    }
                }
                
                Spacer(minLength: 40)
                
                Button {
                    Task {
                        await sharePoll()
                    }
                } label: {
                    Text("Create Poll")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isValid ? Color.blue : Color.gray)
                        .cornerRadius(12)
                }
                .disabled(!isValid)
            }
            .padding()
        }
        .onAppear {
            focusedField = -1
        }
    }
    
    private var isValid: Bool {
        !question.isEmpty && options.filter { !$0.isEmpty }.count >= 2
    }
    
    private func sharePoll() async {
        let validOptions = options.filter { !$0.isEmpty }
        let request = CreatePollRequest(question: question, options: validOptions)
        
        do {
            try await appState.createVibe(
                type: .poll,
                poll: request,
                isLocked: isLocked
            )
            appState.dismissComposer()
        } catch {
            print("Error creating poll: \(error)")
        }
    }
}
