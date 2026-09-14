import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

struct DocumentsView: View {
    @Environment(\.modelContext) private var ctx
    @Bindable var router: Router
    @Query(sort: \DocumentItem.updatedAt, order: .reverse) private var docs: [DocumentItem]
    @State private var gate = BiometricGate.shared
    @State private var filter: DocumentCategory?
    @State private var editing: DocumentItem?
    @State private var unlockTried = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                SectionHeader(title: "Important\nDocuments",
                              subtitle: "Everything in one secure place, so nobody has to search.",
                              onBack: { router.goHome() },
                              trailing: { AnyView(RoundIconButton(icon: "plus") { add() }) })

                if gate.stillValid {
                    filters
                    if docs.isEmpty {
                        QuietEmptyState(icon: "doc.text",
                                        title: "Nothing filed yet",
                                        message: "A will, a deed, a policy. Photograph it or keep a note of where it lives.",
                                        actionTitle: "Add a document") { add() }
                    } else {
                        VStack(spacing: 12) {
                            ForEach(shown) { d in
                                Button { Haptics.tap(); editing = d } label: { DocumentRow(doc: d) }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            d.fileRefs.forEach { MediaStore.delete($0) }
                                            ctx.delete(d); try? ctx.save()
                                        } label: { Label("Delete", systemImage: "trash") }
                                    }
                            }
                        }
                    }
                } else {
                    lockedPanel
                }

                Marginalia(text: KinwardSection.documents.marginalia).padding(.top, 8)
            }
            .padding(.horizontal, 22).padding(.top, 10).padding(.bottom, 190)
        }
        .background(PaperBackground())
        .overlay(alignment: .top) { StatusBarScrim() }
        .task {
            if !unlockTried { unlockTried = true; _ = await gate.unlock(reason: "Open your documents") }
        }
        .sheet(item: $editing) { d in DocumentEditor(doc: d) }
    }

    private var shown: [DocumentItem] {
        guard let f = filter else { return docs }
        return docs.filter { $0.category == f }
    }

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("All", on: filter == nil) { filter = nil }
                ForEach(DocumentCategory.allCases) { c in
                    chip(c.title, on: filter == c) { filter = c }
                }
            }
            .padding(.vertical, 2)
        }
        .fadingTrailingEdge()
    }
    private func chip(_ t: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button { Haptics.tap(); withAnimation(KMotion.gentle) { action() } } label: {
            Text(t).font(KType.body(13.5))
                .foregroundStyle(on ? K.surface : K.inkSoft)
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(Capsule().fill(on ? K.sageDeep : K.surface)
                    .overlay(Capsule().strokeBorder(on ? .clear : K.border, lineWidth: 0.8)))
        }
        .buttonStyle(.plain)
    }

    private var lockedPanel: some View {
        VStack(spacing: 18) {
            Image(systemName: "lock.shield")
                .font(.system(size: 28, weight: .ultraLight)).foregroundStyle(K.gold)
                .frame(width: 74, height: 74)
                .background(Circle().fill(K.surface).overlay(Circle().strokeBorder(K.border, lineWidth: 0.8)))
            Text("Locked").font(.serif(24)).foregroundStyle(K.ink)
            Text("Your documents open with \(gate.biometryName) and stay on this device.")
                .font(KType.body(15)).foregroundStyle(K.inkSoft)
                .multilineTextAlignment(.center).frame(maxWidth: 280).lineSpacing(3)
            KButton(title: "Unlock", icon: "faceid") {
                Task { await gate.unlock(reason: "Open your documents") }
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func add() {
        guard gate.stillValid else {
            Task { await gate.unlock(reason: "Open your documents") }
            return
        }
        let d = DocumentItem(title: "", category: filter ?? .legal)
        ctx.insert(d); editing = d
    }
}

struct DocumentRow: View {
    let doc: DocumentItem
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: doc.category.icon)
                .font(.system(size: 16, weight: .light)).foregroundStyle(K.sage)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(K.bgDeep.opacity(0.7)))
            VStack(alignment: .leading, spacing: 3) {
                Text(doc.title.isEmpty ? "Untitled" : doc.title)
                    .font(KType.body(16).weight(.medium)).foregroundStyle(K.ink).lineLimit(1)
                Text(subtitle).font(KType.caption(12.5)).foregroundStyle(K.inkSoft).lineLimit(1)
            }
            Spacer()
            if !doc.fileRefs.isEmpty {
                ZStack {
                    ForEach(Array(doc.fileRefs.prefix(2).enumerated()), id: \.offset) { i, ref in
                        MediaImage(ref: ref)
                            .frame(width: 34, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(K.surface, lineWidth: 1.2))
                            .rotationEffect(.degrees(Double(i) * 6 - 3))
                            .offset(x: CGFloat(i) * 7)
                    }
                }
                .frame(width: 46)
            }
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .medium))
                .foregroundStyle(K.inkFaint.opacity(0.6))
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .cardSurface(radius: 18)
    }
    private var subtitle: String {
        var bits = [doc.category.title]
        if !doc.fileRefs.isEmpty { bits.append("\(doc.fileRefs.count) page\(doc.fileRefs.count == 1 ? "" : "s")") }
        else if !doc.whereToFind.isEmpty { bits.append(doc.whereToFind) }
        bits.append("Updated \(doc.updatedAt.formatted(.dateTime.month(.abbreviated).year()))")
        return bits.joined(separator: " · ")
    }
}

struct DocumentEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Bindable var doc: DocumentItem
    @State private var showScanner = false

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground(deep: true)
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        FormLabel(text: "What is it")
                        KField(placeholder: "Will, deed, policy…", text: $doc.title, serif: true, size: 18)

                        FormLabel(text: "Category")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(DocumentCategory.allCases) { c in
                                    let on = doc.category == c
                                    Button { Haptics.tap(); doc.category = c } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: c.icon).font(.system(size: 10, weight: .light))
                                            Text(c.title).font(KType.body(13.5))
                                        }
                                        .foregroundStyle(on ? K.surface : K.inkSoft)
                                        .padding(.horizontal, 13).padding(.vertical, 9)
                                        .background(Capsule().fill(on ? K.sageDeep : K.surface)
                                            .overlay(Capsule().strokeBorder(on ? .clear : K.border, lineWidth: 0.8)))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 2)
                        }

                        FormLabel(text: "Pages")
                        PhotoStrip(refs: $doc.fileRefs, height: 130)
                        HStack(spacing: 10) {
                            Button { Haptics.tap(); showScanner = true } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "doc.viewfinder").font(.system(size: 14, weight: .light))
                                    Text("Scan").font(KType.body(14))
                                }
                                .foregroundStyle(K.ink)
                                .padding(.horizontal, 16).padding(.vertical, 11)
                                .background(Capsule().fill(K.surface).overlay(Capsule().strokeBorder(K.border, lineWidth: 0.8)))
                            }
                            .buttonStyle(.plain)
                            PhotoAddButton(label: "From photos", refs: $doc.fileRefs)
                        }

                        FormLabel(text: "Where the original lives")
                        KField(placeholder: "Safe deposit box, second drawer, the notary's office", text: $doc.whereToFind)

                        FormLabel(text: "Notes")
                        KTextArea(placeholder: "Anything that would help the person who has to deal with this.",
                                  text: $doc.note, minHeight: 130, font: KType.body(15))
                    }
                    .padding(.horizontal, 22).padding(.top, 10).padding(.bottom, 50)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { save(); dismiss() }.font(KType.body(15)).foregroundStyle(K.inkSoft)
                }
                ToolbarItem(placement: .principal) { Text("Document").font(.serif(16)).foregroundStyle(K.ink) }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Keep") { save(); Haptics.kept(); dismiss() }
                        .font(KType.body(15).weight(.medium)).foregroundStyle(K.sageDeep)
                }
            }
            .toolbarBackground(K.bg, for: .navigationBar)
        }
        .sheet(isPresented: $showScanner) {
            DocumentScanner { images in
                for img in images { if let ref = MediaStore.saveImage(img) { doc.fileRefs.append(ref) } }
                Haptics.kept()
            }
            .ignoresSafeArea()
        }
    }
    private func save() {
        doc.updatedAt = .now
        if doc.title.isEmpty && doc.fileRefs.isEmpty { ctx.delete(doc) }
        try? ctx.save()
    }
}
