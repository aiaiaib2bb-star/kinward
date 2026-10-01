import SwiftUI

/// The plain alternative to the dial: Home, two sections, the keep button, and More.
///
/// Seven sections do not fit in a tab bar and pretending otherwise makes a cramped
/// one, so the four that do not fit sit behind More along with search and settings.
struct TabBarNav: View {
    @Bindable var router: Router
    var onCapture: () -> Void

    @State private var showMore = false

    var body: some View {
        HStack(spacing: 0) {
            item(icon: "house", title: "Home", on: router.atHome) {
                router.goHome()
            }
            ForEach(NavStyle.barSections) { s in
                item(icon: s.icon, title: s.title, on: !router.atHome && router.section == s) {
                    router.go(s)
                }
            }
            keepItem
            item(icon: "ellipsis", title: "More", on: showMore) {
                showMore = true
            }
        }
        .padding(.top, 10)
        .padding(.horizontal, 6)
        .padding(.bottom, 4)
        .background(
            ZStack {
                // Clear uses the system bar material as-is, the way every tab bar on
                // the phone does; Paper tints it toward its stock.
                Rectangle().fill(K.isClear ? AnyShapeStyle(.bar) : AnyShapeStyle(.ultraThinMaterial))
                if !K.isClear { Rectangle().fill(K.bg.opacity(0.72)) }
                VStack {
                    Rectangle().fill(K.border.opacity(0.7)).frame(height: 0.7)
                    Spacer()
                }
            }
            .ignoresSafeArea(edges: .bottom)
        )
        .tutorialAnchor(.navigation)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .sheet(isPresented: $showMore) {
            MoreSheet(router: router)
                .presentationDetents([.medium, .large])
        }
    }

    private func item(icon: String, title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            withAnimation(KMotion.gentle) { action() }
        } label: {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: on ? .medium : .light))
                    .frame(height: 22)
                Text(title)
                    .font(KType.caption(10.5).weight(on ? .medium : .regular))
                    .lineLimit(1)
            }
            .foregroundStyle(on ? K.sageDeep : K.inkFaint)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// The one thing the app is actually for, so it carries the accent rather than
    /// sitting in the row as another grey glyph.
    private var keepItem: some View {
        Button {
            Haptics.tap()
            onCapture()
        } label: {
            VStack(spacing: 5) {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(K.onAccent)
                    .frame(width: 30, height: 22)
                    .background(Capsule().fill(K.sageDeep))
                Text("Keep")
                    .font(KType.caption(10.5))
                    .foregroundStyle(K.sageDeep)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Everything the bar could not hold, said plainly.
private struct MoreSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var router: Router

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground(deep: true)
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("The rest of it").eyebrowStyle(K.inkFaint).padding(.top, 6)

                        VStack(spacing: 0) {
                            ForEach(Array(NavStyle.moreSections.enumerated()), id: \.element) { i, s in
                                row(icon: s.icon, title: s.title, detail: s.meaning) {
                                    router.go(s)
                                    dismiss()
                                }
                                if i < NavStyle.moreSections.count - 1 { HairLine() }
                            }
                        }
                        .cardSurface()

                        Text("Elsewhere").eyebrowStyle(K.inkFaint).padding(.top, 14)
                        VStack(spacing: 0) {
                            row(icon: "magnifyingglass", title: "Search",
                                detail: "Anything you've kept") {
                                dismiss()
                                router.showSearch = true
                            }
                            HairLine()
                            row(icon: "person.crop.circle", title: "You",
                                detail: "Your name, the icon, how Kinward behaves") {
                                dismiss()
                                router.showSettings = true
                            }
                        }
                        .cardSurface()
                    }
                    .padding(.horizontal, 22).padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }.font(KType.body(15)).foregroundStyle(K.inkSoft)
                }
            }
            .toolbarBackground(K.bg, for: .navigationBar)
        }
    }

    private func row(icon: String, title: String, detail: String,
                     action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .light)).foregroundStyle(K.sage)
                    .frame(width: 40, height: 40)
                    .background(RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(K.bgDeep.opacity(0.7)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(KType.body(16)).foregroundStyle(K.ink)
                    Text(detail).font(KType.caption(12)).foregroundStyle(K.inkSoft)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .medium))
                    .foregroundStyle(K.inkFaint.opacity(0.6))
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
