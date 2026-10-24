import SwiftData
import SwiftUI

/// Central das comemorações: guarda a comemoração em exibição. Fica no `.environment` da `MainTabView`.
@Observable
final class CelebrationCenter {
    struct Event: Identifiable, Equatable {
        let id = UUID()
        let achievements: [Achievement]
        let message: String
    }

    private(set) var current: Event?
    private var dismissTask: Task<Void, Never>?

    func celebrate(_ achievements: [Achievement], message: String) {
        guard !achievements.isEmpty else { return }
        withAnimation(.spring(duration: 0.5, bounce: 0.3)) {
            current = Event(achievements: achievements, message: message)
        }
        // Some sozinha depois de alguns segundos
        dismissTask?.cancel()
        dismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        withAnimation(.easeOut(duration: 0.3)) { current = nil }
    }
}

/// Observa o total de hoje e dispara a comemoração quando uma meta é cruzada.
/// Funciona para qualquer forma de registrar (botão, atalho, aba Refeições, edição).
struct CelebrationWatcher: View {
    let targets: NutritionTargets
    @Environment(CelebrationCenter.self) private var center
    @Query private var todayMeals: [Meal]
    /// Ignora mudanças logo ao abrir (o carregamento inicial não é "conquista").
    @State private var readySince: Date?

    init(targets: NutritionTargets, calendar: Calendar = .current) {
        self.targets = targets
        let start = calendar.startOfDay(for: .now)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        _todayMeals = Query(filter: #Predicate<Meal> { $0.day >= start && $0.day < end })
    }

    private var total: Macros { todayMeals.map(\.macros).total() }

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .task {
                try? await Task.sleep(for: .milliseconds(800))
                readySince = .now
            }
            .onChange(of: total) { before, after in
                guard readySince != nil else { return }
                let achievements = DailyCoach.achievements(before: before, after: after, targets: targets)
                guard !achievements.isEmpty else { return }
                center.celebrate(
                    achievements,
                    message: DailyCoach.celebrationMessage(for: achievements, consumed: after, targets: targets)
                )
            }
    }
}

/// O que aparece na comemoração: aviso no topo + confete (sem confete com "Reduzir Movimento").
struct CelebrationOverlay: View {
    @Environment(CelebrationCenter.self) private var center
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .top) {
            if let event = center.current {
                if !reduceMotion {
                    ConfettiView()
                        .id(event.id) // confete novo a cada comemoração
                        .transition(.opacity)
                }
                CelebrationBanner(event: event) { center.dismiss() }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .sensoryFeedback(.success, trigger: center.current?.id)
    }
}

private struct CelebrationBanner: View {
    let event: CelebrationCenter.Event
    let onClose: () -> Void

    var body: some View {
        Button(action: onClose) {
            HStack(spacing: 14) {
                Image(systemName: event.achievements.first?.symbol ?? "star.fill")
                    .font(.title)
                    .foregroundStyle(.accentForeground)
                    .frame(width: 52, height: 52)
                    .background(Color.accentColor, in: Circle())
                    .symbolEffect(.bounce, value: event.id)
                VStack(alignment: .leading, spacing: 3) {
                    Text(event.achievements.count > 1 ? "Metas batidas!" : (event.achievements.first?.title ?? ""))
                        .font(.headline)
                    Text(event.message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Toque para fechar")
        .accessibilityIdentifier("comemoracao")
    }
}

/// Confete desenhado com Canvas (sem bibliotecas): papéis coloridos caindo com gravidade e balanço.
struct ConfettiView: View {
    private struct Piece {
        let x: Double        // posição inicial (0–1 da largura)
        let vx: Double       // deslocamento lateral (pt/s)
        let vy: Double       // velocidade inicial para baixo (pt/s)
        let delay: Double    // atraso para não caírem todos juntos
        let size: Double
        let spin: Double     // rotação (rad/s)
        let wobble: Double   // frequência do balanço
        let colorIndex: Int
    }

    private static let colors: [Color] = [.accentColor, .pink, .teal, .orange, .yellow, .purple, .green, .blue]
    private static let gravity = 420.0
    private static let duration = 3.2

    @State private var pieces: [Piece] = (0..<90).map { _ in
        Piece(
            x: .random(in: 0...1),
            vx: .random(in: -45...45),
            vy: .random(in: 60...220),
            delay: .random(in: 0...0.5),
            size: .random(in: 7...12),
            spin: .random(in: -7...7),
            wobble: .random(in: 2...5),
            colorIndex: .random(in: 0..<ConfettiView.colors.count)
        )
    }
    @State private var start = Date.now

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSince(start)
            Canvas { context, size in
                guard elapsed < Self.duration else { return }
                for piece in pieces {
                    let t = elapsed - piece.delay
                    guard t > 0 else { continue }
                    let x = piece.x * size.width + piece.vx * t + sin(t * piece.wobble) * 14
                    let y = -20 + piece.vy * t + 0.5 * Self.gravity * t * t
                    guard y < size.height + 20 else { continue }

                    var pieceContext = context
                    pieceContext.opacity = max(0, min(1, (Self.duration - elapsed) / 0.6)) // some no final
                    pieceContext.translateBy(x: x, y: y)
                    pieceContext.rotate(by: .radians(piece.spin * t))
                    let rect = CGRect(x: -piece.size / 2, y: -piece.size / 4, width: piece.size, height: piece.size / 2)
                    pieceContext.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(Self.colors[piece.colorIndex]))
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#Preview {
    let center = CelebrationCenter()
    return Color(.systemGroupedBackground)
        .overlay(alignment: .top) { CelebrationOverlay() }
        .environment(center)
        .onAppear {
            center.celebrate([.proteinGoal], message: "167 g de proteína hoje. É isso que constrói músculo.")
        }
}
