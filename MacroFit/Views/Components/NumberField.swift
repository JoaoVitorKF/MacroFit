import SwiftUI

/// Linha de formulário para números: rótulo, campo com teclado numérico, unidade e mensagem de erro.
/// O erro só aparece depois que algo foi digitado, para não "brigar" com o usuário num formulário vazio.
struct NumberField: View {
    let field: NumericField
    @Binding var text: String
    var placeholder: String = "0"

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(field.label)
                Spacer()
                TextField(placeholder, text: $text)
                    .keyboardType(field.allowsDecimal ? .decimalPad : .numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 110)
                Text(field.unit)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 32, alignment: .leading)
            }
            if !text.isEmpty, let error = field.errorMessage(for: text) {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }
}

/// Barra com o botão "OK" acima do teclado numérico.
struct KeyboardDoneToolbar: ViewModifier {
    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("OK") { hideKeyboard() }
                    .fontWeight(.semibold)
            }
        }
    }
}

extension View {
    func keyboardDoneButton() -> some View {
        modifier(KeyboardDoneToolbar())
    }
}

#Preview {
    @Previewable @State var weight = "72,5"
    @Previewable @State var age = "8"
    Form {
        NumberField(field: .weight, text: $weight)
        NumberField(field: .age, text: $age)
    }
}
