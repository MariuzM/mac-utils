import SwiftUI

struct SidebarScrollFade: ViewModifier {
    let length: CGFloat

    func body(content: Content) -> some View {
        content.mask {
            VStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                    .frame(height: length)
                Rectangle()
                    .fill(.black)
                LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: length)
            }
        }
    }
}

extension View {
    func sidebarScrollFade(length: CGFloat = 14) -> some View {
        modifier(SidebarScrollFade(length: length))
    }
}
