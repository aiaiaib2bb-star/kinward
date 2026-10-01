import SwiftUI
import PhotosUI

// MARK: - Screen chrome

/// The editorial masthead every section opens with.
struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var onBack: (() -> Void)? = nil
    var trailing: (() -> AnyView)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                if let onBack {
                    Button(action: { Haptics.tap(); onBack() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(K.ink)
                            .frame(width: 34, height: 34)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .offset(x: -8)
                }
                Spacer(minLength: 0)
                if let trailing { trailing() }
            }
            .frame(height: onBack == nil && trailing == nil ? 0 : 34)

            Text(title)
                .font(.serif(34))
                .foregroundStyle(K.ink)
                .lineSpacing(-2)
                .fixedSize(horizontal: false, vertical: true)

            if let subtitle {
                Text(subtitle)
                    .font(KType.body(15.5))
                    .foregroundStyle(K.inkSoft)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct RoundIconButton: View {
    let icon: String
    var size: CGFloat = 38
    var action: () -> Void
    var body: some View {
        Button(action: { Haptics.tap(); action() }) {
            Image(systemName: icon)
                .font(.system(size: size * 0.42, weight: .regular))
                .foregroundStyle(K.ink)
                .frame(width: size, height: size)
                .background(Circle().fill(K.surface).overlay(Circle().strokeBorder(K.border, lineWidth: 0.8)))
                .shadow(color: K.shadowInk.opacity(0.05), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }
}

struct QuietEmptyState: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .ultraLight))
                .foregroundStyle(K.gold)
                .frame(width: 62, height: 62)
                .background(Circle().fill(K.surface).overlay(Circle().strokeBorder(K.border, lineWidth: 0.8)))
            Text(title).font(.serif(21)).foregroundStyle(K.ink).multilineTextAlignment(.center)
            Text(message).font(KType.body(14.5)).foregroundStyle(K.inkSoft)
                .multilineTextAlignment(.center).lineSpacing(3)
                .frame(maxWidth: 270)
            if let actionTitle, let action {
                Button(action: { Haptics.tap(); action() }) {
                    Text(actionTitle)
                        .font(KType.body(15)).foregroundStyle(K.onAccent)
                        .padding(.horizontal, 24).padding(.vertical, 12)
                        .background(Capsule().fill(K.sageDeep))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 42)
    }
}

// MARK: - Rows

struct ArchiveRow: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    var imageRef: String? = nil
    var trailingText: String? = nil
    var showsChevron: Bool = true

    var body: some View {
        HStack(spacing: 14) {
            if let imageRef, MediaStore.exists(imageRef) {
                MediaImage(ref: imageRef)
                    .frame(width: 54, height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            } else if let icon {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .light))
                    .foregroundStyle(K.sage)
                    .frame(width: 42, height: 42)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(K.bgDeep.opacity(0.7)))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(KType.body(16).weight(.medium)).foregroundStyle(K.ink)
                    .lineLimit(1)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle).font(KType.caption(13)).foregroundStyle(K.inkSoft).lineLimit(1)
                }
            }
            Spacer(minLength: 6)
            if let trailingText {
                Text(trailingText).font(KType.caption(12)).foregroundStyle(K.inkFaint)
            }
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(K.inkFaint.opacity(0.7))
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
        .cardSurface(radius: 18)
    }
}

// MARK: - Images

struct MediaImage: View {
    let ref: String?
    var body: some View {
        if let img = MediaStore.image(ref) {
            Image(uiImage: img).resizable().scaledToFill()
        } else {
            ZStack {
                LinearGradient(colors: [K.bgDeep, K.goldSoft.opacity(0.55)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: "photo").font(.system(size: 16, weight: .ultraLight)).foregroundStyle(K.inkFaint)
            }
        }
    }
}

struct PersonAvatar: View {
    let person: Person
    var size: CGFloat = 52
    var body: some View {
        AvatarBadge(initials: person.initials, photoRef: person.photoRef,
                    seed: person.seed, size: size)
    }
}

/// The same avatar, drawn from plain values rather than the model.
struct AvatarBadge: View {
    let initials: String
    var photoRef: String?
    var seed: Int = 0
    var size: CGFloat = 52

    var body: some View {
        ZStack {
            if let img = MediaStore.image(photoRef) {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                LinearGradient(colors: tint, startPoint: .topLeading, endPoint: .bottomTrailing)
                Text(initials)
                    .font(.serif(size * 0.36, .regular))
                    .foregroundStyle(K.onAccent.opacity(0.95))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(K.surface.opacity(0.9), lineWidth: 1))
        .shadow(color: K.shadowInk.opacity(0.08), radius: 5, y: 2)
    }
    private var tint: [Color] {
        let palettes: [[Color]] = [
            [K.sage, K.sageDeep], [K.gold, Color(hex: 0x8A7748)],
            [Color(hex: 0x8C8577), Color(hex: 0x5E594E)], [Color(hex: 0x7F8B86), Color(hex: 0x4B5550)]
        ]
        return palettes[abs(seed) % palettes.count]
    }
}

// MARK: - Photo picking

struct PhotoAddButton: View {
    var label: String = "Add photos"
    @Binding var refs: [String]
    @State private var picked: [PhotosPickerItem] = []

    var body: some View {
        PhotosPicker(selection: $picked, maxSelectionCount: 8, matching: .images) {
            HStack(spacing: 8) {
                Image(systemName: "photo.badge.plus").font(.system(size: 14, weight: .light))
                Text(label).font(KType.body(14))
            }
            .foregroundStyle(K.ink)
            .padding(.horizontal, 16).padding(.vertical, 11)
            .background(Capsule().fill(K.surface).overlay(Capsule().strokeBorder(K.border, lineWidth: 0.8)))
        }
        .onChange(of: picked) { _, items in
            guard !items.isEmpty else { return }
            Task {
                var new: [String] = []
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let img = UIImage(data: data), let ref = MediaStore.saveImage(img) {
                        new.append(ref)
                    }
                }
                await MainActor.run { refs.append(contentsOf: new); picked = []; Haptics.kept() }
            }
        }
    }
}

struct PhotoStrip: View {
    @Binding var refs: [String]
    var editable: Bool = true
    var height: CGFloat = 96
    var body: some View {
        if !refs.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(refs, id: \.self) { ref in
                        MediaImage(ref: ref)
                            .frame(width: height * 0.86, height: height)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(alignment: .topTrailing) {
                                if editable {
                                    Button {
                                        Haptics.tap()
                                        withAnimation(KMotion.gentle) { refs.removeAll { $0 == ref } }
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(K.ink)
                                            .frame(width: 20, height: 20)
                                            .background(Circle().fill(K.surface.opacity(0.95)))
                                    }
                                    .buttonStyle(.plain)
                                    .padding(5)
                                }
                            }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }
}

// MARK: - Fields

struct KField: View {
    let placeholder: String
    @Binding var text: String
    var serif: Bool = false
    var size: CGFloat = 16
    /// Vertical, so a long answer wraps onto a second line instead of sliding off
    /// the right-hand edge where the writer can no longer read it.
    var body: some View {
        TextField("", text: $text,
                  prompt: Text(placeholder).foregroundStyle(K.inkFaint.opacity(0.85)),
                  axis: .vertical)
            .lineLimit(1...)
            .font(serif ? .serif(size) : KType.body(size))
            .foregroundStyle(K.ink)
            .autocorrectionDisabled()
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(K.surface))
            .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).strokeBorder(K.border, lineWidth: 0.8))
    }
}

struct KTextArea: View {
    let placeholder: String
    @Binding var text: String
    var minHeight: CGFloat = 150
    var font: Font = KType.body(16)
    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 18, style: .continuous).fill(K.surface)
            RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(K.border, lineWidth: 0.8)
            if text.isEmpty {
                Text(placeholder)
                    .font(font).foregroundStyle(K.inkFaint.opacity(0.85))
                    .padding(.horizontal, 18).padding(.vertical, 18)
                    .allowsHitTesting(false)
            }
            // The box does not scroll: it grows, and the page it sits on carries
            // the writer down to the cursor instead of hiding it under the keyboard.
            TextEditor(text: $text)
                .font(font)
                .foregroundStyle(K.ink)
                .lineSpacing(5)
                .scrollContentBackground(.hidden)
                .scrollDisabled(true)
                .frame(minHeight: minHeight)
                .padding(.horizontal, 13).padding(.vertical, 11)
        }
    }
}

struct FormLabel: View {
    let text: String
    var body: some View {
        Text(text).eyebrowStyle(K.inkFaint).padding(.leading, 2)
    }
}

/// A short wash under the status bar. Content in this app scrolls the whole height
/// of the screen, and without it a card edge or an icon collides with the clock.
struct StatusBarScrim: View {
    var body: some View {
        GeometryReader { geo in
            LinearGradient(colors: [K.bg, K.bg.opacity(0.92), K.bg.opacity(0)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: geo.safeAreaInsets.top + 6)
                .ignoresSafeArea()
        }
        .allowsHitTesting(false)
    }
}

extension View {
    /// Fades a horizontally scrolling row out at the edges, so a half-cut chip reads
    /// as "there is more" rather than as a clipping bug.
    func fadingTrailingEdge() -> some View {
        mask(
            LinearGradient(stops: [
                .init(color: .black, location: 0),
                .init(color: .black, location: 0.90),
                .init(color: .black.opacity(0), location: 1)
            ], startPoint: .leading, endPoint: .trailing)
        )
    }
}
