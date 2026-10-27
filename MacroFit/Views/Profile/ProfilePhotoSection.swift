import PhotosUI
import SwiftUI

/// Topo do Perfil: a foto (toque para escolher da galeria) e o botão de remover.
/// A galeria do `PhotosPicker` roda fora do app, então não precisa pedir permissão de acesso às fotos.
struct ProfilePhotoSection: View {
    @Bindable var profile: UserProfile
    @Environment(\.modelContext) private var context
    @State private var selection: PhotosPickerItem?
    @State private var isLoading = false
    @State private var failed = false

    var body: some View {
        Section {
            HStack(spacing: 16) {
                PhotosPicker(selection: $selection, matching: .images) {
                    ProfileAvatar(data: profile.photoData, size: 76)
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.accentForeground)
                                .frame(width: 26, height: 26)
                                .background(Color.accentColor, in: Circle())
                                .overlay(Circle().strokeBorder(Color(.secondarySystemGroupedBackground), lineWidth: 2))
                        }
                        .overlay {
                            if isLoading { ProgressView() }
                        }
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(profile.photoData == nil ? "Adicionar foto" : "Trocar foto")
                .accessibilityIdentifier("foto-perfil")

                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.photoData == nil ? "Adicionar foto" : "Sua foto")
                        .font(.headline)
                    Text(profile.photoData == nil ? "Toque no círculo para escolher uma foto da galeria." : "Toque na foto para trocar.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if failed {
                        Text("Não deu para usar essa imagem. Tente outra.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    if profile.photoData != nil {
                        Button("Remover foto", role: .destructive) {
                            withAnimation { profile.photoData = nil }
                            try? context.save()
                        }
                        .buttonStyle(.borderless)
                        .font(.subheadline)
                        .padding(.top, 2)
                        .accessibilityIdentifier("remover-foto")
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .onChange(of: selection) { _, item in
            guard let item else { return }
            Task { await load(item) }
        }
    }

    private func load(_ item: PhotosPickerItem) async {
        isLoading = true
        failed = false
        defer {
            isLoading = false
            selection = nil
        }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let prepared = await Task.detached(operation: { ProfilePhoto.prepare(data) }).value
        else {
            failed = true
            return
        }
        withAnimation { profile.photoData = prepared }
        try? context.save()
    }
}

/// Foto redonda do perfil; sem foto, um boneco sobre o destaque.
struct ProfileAvatar: View {
    let data: Data?
    let size: CGFloat

    var body: some View {
        Group {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.45))
                    .foregroundStyle(Color.accentColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.accentColor.opacity(0.15))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}
