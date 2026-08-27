import SwiftUI
import ImagePlayground
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

struct ImageStudioView: View {
    @Environment(\.supportsImagePlayground) private var supportsImagePlayground
    @State private var prompt = ""
    @State private var showingPlayground = false
    @State private var gallery: [URL] = []
    @State private var errorMessage = ""
    @State private var selectedTemplate = ""

    private let templates = [
        ("Report cover", "A polished editorial illustration for a professional annual report, restrained colours, clean composition"),
        ("Presentation concept", "A sophisticated conceptual illustration for a business presentation, minimal, modern and clear"),
        ("Campaign visual", "A premium campaign illustration with a strong focal point and generous space for a headline"),
        ("Project moodboard", "A cohesive professional moodboard showing materials, colours and visual direction")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AegisDeviceClass.current == .phone ? 9 : 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Creative Studio").font(AegisDeviceClass.current == .phone ? .title2.bold() : .largeTitle.bold())
                    Text("Generate professional visuals with Apple’s system Image Playground.")
                        .font(AegisDeviceClass.current == .phone ? .caption : .body)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label(selectedTemplate.isEmpty ? "New visual" : selectedTemplate, systemImage: "wand.and.stars")
                            .font(.headline)
                        Spacer()
                        if !prompt.isEmpty {
                            Button("Clear", systemImage: "xmark.circle.fill") {
                                prompt = ""
                                selectedTemplate = ""
                            }
                            .labelStyle(.iconOnly)
                            .foregroundStyle(.secondary)
                        }
                    }
                    TextField("Describe the image you need", text: $prompt, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(2...4)
                        .padding(10)
                        .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    HStack {
                        Text("\(prompt.count) characters")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Generate image", systemImage: "wand.and.stars") { showingPlayground = true }
                            .buttonStyle(AegisPrimaryButtonStyle())
                            .disabled(!supportsImagePlayground || prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        if !supportsImagePlayground {
                            Text("Image Playground is unavailable on this device or language.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if !errorMessage.isEmpty { Text(errorMessage).font(.caption).foregroundStyle(.red) }
                }
                .padding(AegisDeviceClass.current == .phone ? 10 : 14)
                .glassEffect(.regular.tint(.accentColor.opacity(0.10)).interactive(), in: RoundedRectangle(cornerRadius: 18))

                Text("Professional templates").font(.headline)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: AegisDeviceClass.current == .phone ? 145 : 220), spacing: 7)], spacing: 7) {
                    ForEach(templates, id: \.0) { template in
                        Button {
                            prompt = template.1
                            selectedTemplate = template.0
                        } label: {
                            HStack(spacing: 7) {
                                Image(systemName: "rectangle.and.pencil.and.ellipsis").foregroundStyle(.purple)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(template.0).font(.subheadline.weight(.semibold)).lineLimit(2)
                                    Text("Use template").font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
                            .padding(9)
                            .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 14))
                        }.buttonStyle(.plain)
                    }
                }

                HStack {
                    Text("Generated gallery").font(.headline)
                    Spacer()
                    Text("Stored locally").font(.caption).foregroundStyle(.secondary)
                }
                if gallery.isEmpty {
                    ContentUnavailableView("No generated images", systemImage: "photo.stack", description: Text("Images you accept from Image Playground appear here."))
                        .frame(minHeight: AegisDeviceClass.current == .phone ? 110 : 180)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                        ForEach(gallery, id: \.self) { url in
                            GeneratedImageCard(url: url) { revisedURL in
                                saveGeneratedImage(from: revisedURL)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: AegisLayout.contentMaxWidth(1000), alignment: .leading)
        }
        .contentMargins(AegisLayout.pagePadding, for: .scrollContent)
        .background { AppleEditorialBackground() }
        .navigationTitle("Creative Studio")
        .navigationBarTitleDisplayMode(.inline)
        .task { loadGallery() }
        .imagePlaygroundSheet(isPresented: $showingPlayground, concept: prompt, sourceImage: nil) { temporaryURL in
            saveGeneratedImage(from: temporaryURL)
        }
    }

    private func galleryFolder() throws -> URL {
        let root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let folder = root.appendingPathComponent("GeneratedImages", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private func loadGallery() {
        do {
            gallery = try FileManager.default.contentsOfDirectory(at: galleryFolder(), includingPropertiesForKeys: [.creationDateKey])
                .filter { ["png", "jpg", "jpeg", "heic"].contains($0.pathExtension.lowercased()) }
                .sorted { $0.lastPathComponent > $1.lastPathComponent }
        } catch { errorMessage = error.localizedDescription }
    }

    private func saveGeneratedImage(from source: URL) {
        do {
            let ext = source.pathExtension.isEmpty ? "png" : source.pathExtension
            let destination = try galleryFolder().appendingPathComponent("aegis-\(UUID().uuidString).\(ext)")
            try FileManager.default.copyItem(at: source, to: destination)
            gallery.insert(destination, at: 0)
        } catch { errorMessage = "The generated image could not be saved: \(error.localizedDescription)" }
    }
}

private struct GeneratedImageCard: View {
    let url: URL
    let saveRevision: (URL) -> Void
    @Environment(\.supportsImagePlayground) private var supportsImagePlayground
    @State private var showingRefinement = false

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            localImage
                .aspectRatio(1, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            HStack {
                Button("Refine", systemImage: "wand.and.stars") { showingRefinement = true }
                    .buttonStyle(AegisSecondaryButtonStyle())
                    .disabled(!supportsImagePlayground)
                Spacer()
                ShareLink(item: url) { Image(systemName: "square.and.arrow.up") }
                    .buttonStyle(AegisIconButtonStyle())
            }
        }
        .padding(10)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 18))
        .imagePlaygroundSheet(
            isPresented: $showingRefinement,
            concept: "Refine this image into a polished professional visual while preserving its main subject",
            sourceImageURL: url
        ) { revisedURL in
            saveRevision(revisedURL)
        }
    }

    @ViewBuilder
    private var localImage: some View {
        #if canImport(AppKit)
        if let image = NSImage(contentsOf: url) { Image(nsImage: image).resizable() }
        else { Color.secondary.opacity(0.1) }
        #elseif canImport(UIKit)
        if let image = UIImage(contentsOfFile: url.path) { Image(uiImage: image).resizable() }
        else { Color.secondary.opacity(0.1) }
        #endif
    }
}
