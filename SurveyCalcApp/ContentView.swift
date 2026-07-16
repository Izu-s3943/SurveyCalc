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

            IntersectionCalculationView()
                .tabItem { Label("交点計算", systemImage: "point.topleft.down.curvedto.point.bottomright.up") }

            RadialCalculationView()
                .tabItem { Label("放射計算", systemImage: "dot.radiowaves.left.and.right") }
        }
    }
}

#Preview {
    ContentView()
}
