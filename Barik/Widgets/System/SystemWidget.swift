import SwiftUI

/// Widget displaying the Apple logo that opens System Settings when clicked.
struct SystemWidget: View {
    var body: some View {
        Image(systemName: "apple.logo")
            .font(.system(size: 15))
            .foregroundStyle(.foregroundOutside)
            .shadow(color: .foregroundShadowOutside, radius: 3)
            .offset(y: -1)
            .contentShape(Rectangle())
            .experimentalConfiguration(cornerRadius: 15)
            .frame(maxHeight: .infinity)
            .background(.black.opacity(0.001))
            .onTapGesture {
                openSystemSettings()
            }
    }

    private func openSystemSettings() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
    }
}

struct SystemWidget_Previews: PreviewProvider {
    static var previews: some View {
        SystemWidget()
            .frame(width: 100, height: 100)
            .background(Color.black)
    }
}
