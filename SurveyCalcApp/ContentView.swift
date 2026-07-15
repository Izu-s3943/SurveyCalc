import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            DistanceBearingView()
                .tabItem { Label("距離・方位角", systemImage: "ruler") }

            CoordinateConversionView()
                .tabItem { Label("座標変換", systemImage: "arrow.left.arrow.right") }

            AreaCalculationView()
                .tabItem { Label("面積計算", systemImage: "square.dashed") }
        }
    }
}

#Preview {
    ContentView()
}
