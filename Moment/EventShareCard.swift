import SwiftUI
import UIKit

struct EventImageShareSheet: View {
    let event: CountdownEvent

    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var renderFailed = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: .black.opacity(0.3), radius: 18, y: 8)
                        .padding(.horizontal, 22)

                    ShareLink(item: Image(uiImage: image),
                              preview: SharePreview(event.title, image: Image(uiImage: image))) {
                        Label("Поделиться карточкой", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .background(Palette.aqua, in: Capsule())
                            .foregroundStyle(Palette.background)
                    }
                    .padding(.horizontal, 22)
                } else if renderFailed {
                    ContentUnavailableView("Не удалось создать карточку", systemImage: "photo.badge.exclamationmark")
                } else {
                    ProgressView("Подготовка карточки…")
                        .tint(Palette.aqua)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Palette.background)
            .navigationTitle("Карточка события")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .task { renderCard() }
    }

    @MainActor
    private func renderCard() {
        guard image == nil else { return }
        let renderer = ImageRenderer(
            content: EventShareCard(event: event, now: .now)
                .frame(width: 360, height: 640)
        )
        renderer.scale = 3
        renderer.isOpaque = true
        image = renderer.uiImage
        renderFailed = image == nil
    }
}

private struct EventShareCard: View {
    let event: CountdownEvent
    let now: Date

    private var targetDate: Date { event.nextOccurrence(after: now) }
    private var remaining: CountdownComponents { CountdownComponents(deadline: targetDate, now: now) }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Palette.background, Palette.surface, event.theme.color.opacity(0.35)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            if let data = event.photoData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
                    .frame(width: 360, height: 640).clipped().overlay(.black.opacity(0.65))
            }
            Circle()
                .fill(event.theme.color.opacity(0.22))
                .frame(width: 350, height: 350)
                .blur(radius: 2)
                .offset(x: 170, y: -230)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("MOMENT")
                        .font(.system(size: 13, weight: .bold))
                        .tracking(5)
                        .foregroundStyle(event.theme.color)
                    Spacer()
                    Image(systemName: event.symbol)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(event.theme.color)
                        .frame(width: 48, height: 48)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                }

                Spacer(minLength: 24)

                Text(event.repeatsAnnually ? "СЛЕДУЮЩАЯ ДАТА" : "ДО ВАШЕГО СОБЫТИЯ")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2.5)
                    .foregroundStyle(.white.opacity(0.58))
                    .padding(.bottom, 12)
                Text(event.title)
                    .font(.system(size: 38, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .minimumScaleFactor(0.68)

                Spacer(minLength: 32)

                if remaining.isFinished {
                    Text("МОМЕНТ НАСТАЛ")
                        .font(.system(size: 25, weight: .semibold, design: .rounded))
                        .foregroundStyle(event.theme.color)
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        unit(remaining.days, caption: "ДНИ")
                        separator
                        unit(remaining.hours, caption: "ЧАСЫ")
                        separator
                        unit(remaining.minutes, caption: "МИН")
                        separator
                        unit(remaining.seconds, caption: "СЕК")
                    }
                }

                Spacer(minLength: 28)

                Rectangle()
                    .fill(.white.opacity(0.14))
                    .frame(height: 1)
                    .padding(.bottom, 18)
                Text(targetDate.formatted(date: .long, time: .shortened))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                if event.repeatsAnnually {
                    Text("ПОВТОРЯЕТСЯ КАЖДЫЙ ГОД")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.7)
                        .foregroundStyle(event.theme.color)
                        .padding(.top, 12)
                }
                Spacer(minLength: 4)
            }
            .padding(32)
        }
        .frame(width: 360, height: 640)
        .clipShape(RoundedRectangle(cornerRadius: 28))
    }

    private func unit(_ value: Int, caption: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(format: "%02d", value))
                .font(.system(size: 36, weight: .light, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.65)
                .lineLimit(1)
                .foregroundStyle(.white)
            Text(caption)
                .font(.system(size: 8, weight: .bold))
                .tracking(1.3)
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var separator: some View {
        Text(":")
            .font(.system(size: 24, weight: .ultraLight))
            .foregroundStyle(.white.opacity(0.35))
            .accessibilityHidden(true)
    }
}
