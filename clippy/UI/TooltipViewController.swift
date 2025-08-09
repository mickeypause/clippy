import AppKit
import SwiftUI

class TooltipViewController: NSViewController {
    private var tooltipWindow: NSWindow?
    private var hostingController: NSHostingController<TooltipView>?
    private let viewModel = TooltipViewModel()
    
    override func loadView() {
        view = NSView()
    }
    
    func showTooltip(at position: CGRect, originalText: String, transformedText: String? = nil, onAccept: @escaping (String) -> Void) {
        hideTooltip()
        
        viewModel.originalText = originalText
        viewModel.onAccept = onAccept
        
        if let transformedText = transformedText {
            viewModel.showResult(transformedText)
        } else {
            viewModel.showLoading()
        }
        
        let tooltipView = TooltipView(viewModel: viewModel)
        hostingController = NSHostingController(rootView: tooltipView)
        
        let windowRect = CGRect(
            x: position.origin.x,
            y: position.origin.y + position.height + 10,
            width: min(max(300, CGFloat(originalText.count) * 8), 500),
            height: 120
        )
        
        tooltipWindow = NSWindow(
            contentRect: windowRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        guard let window = tooltipWindow, let controller = hostingController else { return }
        
        window.contentViewController = controller
        window.level = .floating
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isOpaque = false
        window.ignoresMouseEvents = false
        
        window.makeKeyAndOrderFront(nil)
        
        // Auto-hide after 30 seconds if no interaction
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            if self?.viewModel.state == .loading {
                self?.hideTooltip()
            }
        }
    }
    
    func updateWithResult(_ text: String) {
        viewModel.showResult(text)
    }
    
    func hideTooltip() {
        tooltipWindow?.close()
        tooltipWindow = nil
        hostingController = nil
        viewModel.reset()
    }
}

enum TooltipState: Equatable {
    case loading
    case result(String)
    case hidden
}

class TooltipViewModel: ObservableObject {
    @Published var state: TooltipState = .hidden
    @Published var originalText: String = ""
    
    var onAccept: ((String) -> Void)?
    
    func showLoading() {
        state = .loading
    }
    
    func showResult(_ text: String) {
        state = .result(text)
    }
    
    func acceptTransformation() {
        if case .result(let text) = state {
            onAccept?(text)
        }
    }
    
    func reset() {
        state = .hidden
        originalText = ""
        onAccept = nil
    }
}

struct TooltipView: View {
    @ObservedObject var viewModel: TooltipViewModel
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 12) {
            switch viewModel.state {
            case .loading:
                loadingView
            case .result(let transformedText):
                resultView(transformedText)
            case .hidden:
                EmptyView()
            }
        }
        .padding(16)
        .background(backgroundColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color(NSColor.controlBackgroundColor) : .white
    }
    
    private var loadingView: some View {
        HStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
                .progressViewStyle(CircularProgressViewStyle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Transforming text...")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("\"\(viewModel.originalText.prefix(50))\(viewModel.originalText.count > 50 ? "..." : "")\"")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
    }
    
    private func resultView(_ transformedText: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Transformation Complete")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("✕") {
                    viewModel.reset()
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            
            ScrollView {
                Text(transformedText)
                    .font(.body)
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(6)
            }
            .frame(maxHeight: 60)
            
            HStack {
                Button("Cancel") {
                    viewModel.reset()
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Accept & Replace") {
                    viewModel.acceptTransformation()
                    viewModel.reset()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
    }
}

#Preview {
    TooltipView(viewModel: {
        let vm = TooltipViewModel()
        vm.originalText = "Hello world this is a test"
        vm.showResult("Hello world! This is a test with improved punctuation and formatting.")
        return vm
    }())
    .frame(width: 400, height: 120)
}