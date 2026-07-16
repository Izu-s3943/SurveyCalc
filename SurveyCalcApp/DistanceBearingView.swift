import SwiftUI

struct DistanceBearingView: View {
    @AppStorage("selectedZone") private var zoneNumber: Int = 9

    @State private var nameA = "測点A"
    @State private var xA: Double = 0
    @State private var yA: Double = 0

    @State private var nameB = "測点B"
    @State private var xB: Double = 0
    @State private var yB: Double = 0

    @StateObject private var locationManagerA = LocationManager()
    @StateObject private var locationManagerB = LocationManager()

    private var result: (distance: Double, bearing: Double) {
        GeoMath.distanceAndBearing(
            from: PlaneCoordinate2D(x: xA, y: yA),
            to: PlaneCoordinate2D(x: xB, y: yB)
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("平面直角座標系") {
                    ZonePickerView(zoneNumber: $zoneNumber)
                }

                Section("起点") {
                    PointEntryCard(title: "起点名", name: $nameA, x: $xA, y: $yA,
                                   zoneNumber: zoneNumber, locationManager: locationManagerA)
                        .listRowInsets(EdgeInsets())
                        .padding(.vertical, 4)
                }

                Section("終点") {
                    PointEntryCard(title: "終点名", name: $nameB, x: $xB, y: $yB,
                                   zoneNumber: zoneNumber, locationManager: locationManagerB)
                        .listRowInsets(EdgeInsets())
                        .padding(.vertical, 4)
                }

                Section("計算結果") {
                    LabeledContent("距離") {
                        Text("\(result.distance.m3) m")
                            .font(.title3.monospacedDigit())
                            .bold()
                    }
                    LabeledContent("方位角(真北基準)") {
                        Text(GeoMath.decimalToDMSString(result.bearing))
                            .font(.title3.monospacedDigit())
                            .bold()
                    }
                }
            }
            .navigationTitle("距離・方位角")
            .withKeyboardDoneButton()
        }
    }
}

#Preview {
    DistanceBearingView()
}
