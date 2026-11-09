import SwiftUI

struct WidgetGuide: View {
    @EnvironmentObject private var store: EventStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if !store.widgetsAvailable {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("События сохраняются на iPhone", systemImage: "checkmark.shield")
                                .font(.headline)
                            Text("Эта установка не поддерживает виджеты. Создавайте и редактируйте события в приложении — они сохранятся после закрытия.")
                                .font(.subheadline)
                        }
                        .foregroundStyle(Palette.aqua)
                        .padding(20)
                        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 20))
                    }
                    VStack(spacing: 18) {
                        Image(systemName: "lock.fill").font(.title2).foregroundStyle(Palette.aqua)
                        Text("Ближе с каждой\nсекундой.")
                            .font(.system(size: 34, weight: .semibold, design: .rounded))
                            .multilineTextAlignment(.center)
                        VStack(alignment: .leading, spacing: 7) {
                            Label("Большое путешествие", systemImage: "airplane")
                                .font(.system(size: 13, weight: .medium))
                            Text(timerInterval: Date.now...Date.now.addingTimeInterval(802_800),
                                 countsDown: true, showsHours: true)
                                .font(.system(size: 33, weight: .light, design: .rounded)).monospacedDigit()
                            Text("ЧАСЫ : МИНУТЫ : СЕКУНДЫ")
                                .font(.system(size: 8, weight: .medium)).tracking(1.5).opacity(0.6)
                        }
                        .padding(20).foregroundStyle(Palette.aqua)
                        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 20))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Palette.aqua.opacity(0.2)))
                        Text("ПРИМЕР ВИДЖЕТА").font(.system(size: 9, weight: .semibold)).tracking(2)
                            .foregroundStyle(Palette.muted)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    step(1, "Создайте событие", "Укажите название, дату, время и секунды.")
                    step(2, "Откройте настройки экрана", "Зажмите экран блокировки → «Настроить» → экран блокировки → область виджетов под часами.")
                    step(3, "Выберите Moment", "Добавьте прямоугольный виджет. Нажмите на него в режиме настройки, чтобы выбрать событие.")
                    step(4, "Или добавьте на главный экран", "Зажмите пустую область → «Изменить» или «+» → «Добавить виджет» → Moment. Доступны маленький и средний размеры.")
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Как работают секунды", systemImage: "info.circle")
                            .font(.subheadline.weight(.semibold))
                        Text("Системный таймер показывает общее число часов, минуты и секунды. Например, 9 дней — это 216 часов. В приложении дни выделены отдельно.")
                        Text("iOS сама обновляет таймер. В Always-On, энергосбережении и при сниженной частоте обновления секунды могут быть скрыты или обновляться реже. Приложение не может принудительно изменить это поведение.")
                        Text("После окончания отсчёт останавливается на нуле. Обновление подписи и смена события в виджете могут происходить с задержкой iOS.")
                    }
                    .font(.footnote).foregroundStyle(Palette.muted)
                    .padding(20).background(Palette.surface, in: RoundedRectangle(cornerRadius: 20))
                }
                .padding(24)
                .frame(maxWidth: 640).frame(maxWidth: .infinity)
            }
            .background(Palette.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Готово") { dismiss() } } }
        }
        .preferredColorScheme(.dark)
    }

    private func step(_ number: Int, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text("\(number)").font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.aqua).frame(width: 32, height: 32)
                .background(Palette.aqua.opacity(0.1), in: Circle())
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.system(size: 16, weight: .semibold))
                Text(text).font(.system(size: 14)).foregroundStyle(Palette.muted)
            }
        }
    }
}
