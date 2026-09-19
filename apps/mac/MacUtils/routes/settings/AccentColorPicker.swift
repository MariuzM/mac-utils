import SwiftUI

struct AccentColorPicker: View {
    @Binding var accent: UIAccentColor

    var body: some View {
        LabeledContent {
            HStack(spacing: 8) {
                ForEach(UIAccentColor.allCases) { option in
                    Button {
                        accent = option
                    } label: {
                        AccentSwatch(accent: option, size: 16)
                            .overlay {
                                if accent == option {
                                    Circle()
                                        .fill(.white)
                                        .frame(width: 6, height: 6)
                                        .shadow(color: .black.opacity(0.3), radius: 0.5)
                                }
                            }
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help(option.name)
                    .accessibilityLabel(option.name)
                    .accessibilityAddTraits(accent == option ? .isSelected : [])
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text("Accent color")
                Text(accent.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct AccentSwatch: View {
    let accent: UIAccentColor
    var size: CGFloat = 11

    var body: some View {
        Group {
            if let color = accent.nsColor {
                Circle().fill(Color(nsColor: color))
            } else {
                Circle().fill(AngularGradient(colors: wheelColors, center: .center))
            }
        }
        .frame(width: size, height: size)
        .overlay {
            Circle().stroke(Color.primary.opacity(0.16), lineWidth: 0.5)
        }
    }

    private var wheelColors: [Color] {
        let colors = UIAccentColor.swatchColors.compactMap(\.nsColor).map { Color(nsColor: $0) }
        return colors + colors.prefix(1)
    }
}
