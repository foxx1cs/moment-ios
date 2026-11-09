import SwiftUI

struct CountdownDisplay: View {
    let components: CountdownComponents
    var compact = false

    var body: some View {
        HStack(alignment: .top, spacing: compact ? 5 : 8) {
            unit(components.days, label: "ДНИ")
            separator
            unit(components.hours, label: "ЧАСЫ")
            separator
            unit(components.minutes, label: "МИН")
            separator
            unit(components.seconds, label: "СЕК")
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Осталось: \(components.days) дней, \(components.hours) часов, \(components.minutes) минут, \(components.seconds) секунд")
    }

    private func unit(_ value: Int, label: String) -> some View {
        VStack(spacing: 8) {
            Text(String(format: "%02d", value))
                .font(.system(size: compact ? 28 : 44, weight: .light, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.45)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.5)
                .opacity(0.55)
        }
    }

    private var separator: some View {
        Text(":")
            .font(.system(size: compact ? 24 : 34, weight: .ultraLight))
            .opacity(0.3)
            .padding(.top, compact ? 0 : 4)
            .accessibilityHidden(true)
    }
}

struct EventHero: View {
    let event: CountdownEvent
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Image(systemName: event.symbol)
                    .font(.system(size: 24, weight: .medium))
                    .frame(width: 52, height: 52)
                    .background(.white.opacity(0.28), in: RoundedRectangle(cornerRadius: 18))
                Spacer()
                Label(event.date > now ? "В ПРЕДВКУШЕНИИ" : "МОМЕНТ НАСТАЛ", systemImage: "circle.fill")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1)
                    .labelStyle(StatusLabelStyle())
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(event.title)
                    .font(.system(size: 29, weight: .semibold, design: .rounded))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(event.date.formatted(.dateTime.day().month(.wide).year().hour().minute().second()))
                    .font(.subheadline)
                    .opacity(0.65)
            }
            CountdownDisplay(components: event.remaining(at: now))
            GeometryReader { geometry in
                Capsule().fill(Palette.ink.opacity(0.10))
                Capsule().fill(Palette.ink.opacity(0.6))
                    .frame(width: max(0, geometry.size.width * event.progress(at: now)))
            }
            .frame(height: 3)
            .accessibilityHidden(true)
            HStack {
                Text(event.date > now ? "Каждая секунда приближает" : "Время создавать новые воспоминания")
                    .font(.system(size: 11))
                Spacer(minLength: 4)
                Image(systemName: "arrow.up.right")
            }
            .opacity(0.6)
        }
        .padding(24)
        .foregroundStyle(Palette.ink)
        .background {
            RoundedRectangle(cornerRadius: 30)
                .fill(LinearGradient(colors: [event.theme.color, event.theme.color.opacity(0.82)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(alignment: .topTrailing) {
                    Circle().stroke(.white.opacity(0.12), lineWidth: 45)
                        .frame(width: 220, height: 220).offset(x: 90, y: -100)
                        .clipped()
                }
                .clipShape(RoundedRectangle(cornerRadius: 30))
        }
        .contentShape(RoundedRectangle(cornerRadius: 30))
    }
}

private struct StatusLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon.font(.system(size: 5))
            configuration.title
        }
    }
}
