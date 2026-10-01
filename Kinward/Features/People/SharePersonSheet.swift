import SwiftData
import SwiftUI

/// Hands somebody everything they're allowed to see, as one file.
///
/// It builds the parcel and stops there. Kinward has no way to send anything by
/// itself and no account to send it through — you choose the app, the address and
/// the moment, the same as any other file on the phone.
struct SharePersonSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx
    @Query private var profiles: [UserProfile]
    @Bindable var person: Person

    @State private var everything = false
    @State private var parcel: LegacyExport.Parcel?
    @State private var bundle: URL?
    @State private var working = false
    @State private var failure: String?

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground(deep: true)
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        header
                        addressBlock
                        scopeBlock
                        contentsBlock
                        if let p = parcel, p.sealedHeld > 0 { sealedBlock(p.sealedHeld) }
                        actions
                        Marginalia(text: "Yours to give.\nNobody takes it.")
                            .padding(.top, 2)
                    }
                    .padding(.horizontal, 22).padding(.bottom, 60)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }.font(KType.body(15)).foregroundStyle(K.inkSoft)
                }
                ToolbarItem(placement: .principal) {
                    Text("Share").font(.serif(16)).foregroundStyle(K.ink)
                }
            }
            .toolbarBackground(K.bg, for: .navigationBar)
        }
        .onAppear(perform: refresh)
        .onChange(of: everything) { _, _ in refresh() }
        .alert("It couldn't be prepared", isPresented: Binding(
            get: { failure != nil }, set: { if !$0 { failure = nil } }
        )) {
            Button("All right", role: .cancel) { failure = nil }
        } message: {
            Text(failure ?? "")
        }
    }

    // MARK: Who

    private var header: some View {
        VStack(alignment: .leading, spacing: 13) {
            PersonAvatar(person: person, size: 66).padding(.top, 4)
            Text("For \(person.name.isEmpty ? "them" : person.name)")
                .font(.serif(28)).foregroundStyle(K.ink)
            Text("One file holding everything they're allowed to see — the writing typeset to read, the recordings as playable files, the photographs and any documents.")
                .font(KType.body(15)).foregroundStyle(K.inkSoft).lineSpacing(3)
        }
    }

    private var addressBlock: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Send it to").eyebrowStyle()
            KField(placeholder: "Their email or iCloud address", text: $person.trustedEmail)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .onChange(of: person.trustedEmail) { _, _ in try? ctx.save() }
            Text("Kept here so it's to hand when you send. Kinward never sends anything on its own.")
                .font(KType.caption(12)).foregroundStyle(K.inkFaint).lineSpacing(2)
        }
    }

    // MARK: How much

    private var scopeBlock: some View {
        Toggle(isOn: $everything.animation(KMotion.gentle)) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Send everything").font(KType.body(15)).foregroundStyle(K.ink)
                Text(everything
                     ? "The whole archive, whatever they were granted."
                     : "Off: only the areas you've opened to \(person.firstName.isEmpty ? "them" : person.firstName).")
                    .font(KType.caption(12)).foregroundStyle(K.inkSoft).lineSpacing(2)
            }
        }
        .tint(K.sage)
        .padding(.horizontal, 16).padding(.vertical, 13)
        .cardSurface(radius: 15)
    }

    // MARK: What's in it

    @ViewBuilder
    private var contentsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What goes in").eyebrowStyle()
            if let p = parcel, !p.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(p.filled.enumerated()), id: \.element.name) { i, section in
                        if i > 0 { HairLine() }
                        HStack(spacing: 10) {
                            if LegacyExport.sensitiveAreas.contains(section.name) {
                                Image(systemName: "lock.fill").font(.system(size: 8)).foregroundStyle(K.gold)
                            }
                            Text(section.name).font(KType.body(15)).foregroundStyle(K.ink)
                            Spacer()
                            Text("\(section.pieces.count)")
                                .font(KType.body(15)).foregroundStyle(K.inkFaint)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)
                    }
                }
                .cardSurface()
                Text(tally(p)).font(KType.caption(12)).foregroundStyle(K.inkSoft)
            } else {
                QuietEmptyState(icon: "tray",
                                title: "Nothing to send yet",
                                message: everything
                                    ? "There's nothing in Kinward to gather up."
                                    : "\(person.firstName.isEmpty ? "They" : person.firstName) hasn't been given access to anything. Open an area on their card, or turn on Send everything.")
            }
        }
    }

    private func tally(_ p: LegacyExport.Parcel) -> String {
        var bits = ["\(p.pieceCount) piece\(p.pieceCount == 1 ? "" : "s")"]
        let voice = p.audioRefs.filter { MediaStore.exists($0) }.count
        let photos = p.photoRefs.filter { MediaStore.exists($0) }.count
        let files = p.fileRefs.filter { MediaStore.exists($0) }.count
        if voice > 0 { bits.append("\(voice) recording\(voice == 1 ? "" : "s")") }
        if photos > 0 { bits.append("\(photos) photo\(photos == 1 ? "" : "s")") }
        if files > 0 { bits.append("\(files) file\(files == 1 ? "" : "s")") }
        return bits.joined(separator: " · ")
    }

    private func sealedBlock(_ count: Int) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.circle").font(.system(size: 14, weight: .light)).foregroundStyle(K.gold)
            Text("\(count) sealed letter\(count == 1 ? " stays" : "s stay") behind. They were written to be opened at a particular moment, and that was the whole point of them.")
                .font(KType.body(14)).foregroundStyle(K.ink).lineSpacing(3)
        }
        .padding(16)
        .cardSurface(radius: K.rLarge, fill: K.paper)
    }

    // MARK: Making it

    @ViewBuilder
    private var actions: some View {
        if let bundle {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    Haptics.tap()
                    SystemShare.present(bundle)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up").font(.system(size: 13, weight: .medium))
                        Text("Send it").font(KType.body(16))
                    }
                    .foregroundStyle(K.onAccent)
                    .frame(maxWidth: .infinity).padding(.vertical, 15)
                    .background(Capsule().fill(K.sageDeep))
                }
                .buttonStyle(.plain)
                Text("\(bundle.lastPathComponent) · \(size(of: bundle)) — ready to send however you like.")
                    .font(KType.caption(12)).foregroundStyle(K.inkSoft).lineSpacing(2)
                Button("Build it again") { self.bundle = nil }
                    .font(KType.body(14)).foregroundStyle(K.inkFaint)
            }
        } else if let p = parcel, !p.isEmpty {
            Button(action: prepare) {
                HStack(spacing: 8) {
                    if working { ProgressView().tint(K.onAccent) }
                    Text(working ? "Gathering it up…" : "Prepare the parcel").font(KType.body(16))
                }
                .foregroundStyle(K.onAccent)
                .frame(maxWidth: .infinity).padding(.vertical, 15)
                .background(Capsule().fill(K.sageDeep))
            }
            .buttonStyle(.plain)
            .disabled(working)
        }
    }

    private func size(of url: URL) -> String {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        let bytes = (attrs?[.size] as? NSNumber)?.int64Value ?? 0
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func refresh() {
        bundle = nil
        parcel = LegacyExport.parcel(for: person, everything: everything,
                                     from: profiles.first, in: ctx)
    }

    private func prepare() {
        guard let parcel, !parcel.isEmpty else { return }
        Task {
            // A parcel carrying financial, legal or account information is exactly the
            // thing the app keeps behind Face ID. Building one asks the same question.
            if parcel.includesSensitive {
                let ok = await BiometricGate.shared.unlock(
                    reason: "Put private information into a file you can send")
                guard ok else { return }
            }
            working = true
            do {
                let url = try await Task.detached(priority: .userInitiated) {
                    try LegacyExport.write(parcel)
                }.value
                bundle = url
                Haptics.kept()
            } catch {
                failure = error.localizedDescription
            }
            working = false
        }
    }
}

/// The system share sheet, presented through UIKit.
///
/// `ShareLink` is the natural thing to reach for, but this view is already several
/// sheets deep — person, then share — and SwiftUI will not put another presentation
/// on top of that. Handing the file to the topmost view controller always works.
@MainActor
enum SystemShare {
    static func present(_ url: URL) {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              var top = (scene.keyWindow ?? scene.windows.first)?.rootViewController
        else { return }
        while let above = top.presentedViewController { top = above }

        let sheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        // iPad needs somewhere to point the popover.
        sheet.popoverPresentationController?.sourceView = top.view
        sheet.popoverPresentationController?.sourceRect =
            CGRect(x: top.view.bounds.midX, y: top.view.bounds.maxY - 60, width: 1, height: 1)
        top.present(sheet, animated: true)
    }
}
