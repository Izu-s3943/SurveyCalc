import SwiftUI

/// 視準点1件分の入力(後視方向からの水平角と距離)
struct SightPoint: Identifiable {
    let id = UUID()
    var name: String
    var angle: Double = 0     // 後視方向からの水平角(度、時計回り)
    var distance: Double = 0  // 器械点からの水平距離(m)
}

struct RadialCalculationView: View {
    @AppStorage("selectedZone") private var zoneNumber: Int = 9

    // 器械点
    @State private var stationName = "器械点"
    @State private var stationX: Double = 0
    @State private var stationY: Double = 0
    @StateObject private var stationLocationManager = LocationManager()

    // 後視点(バック点)
    @State private var backsightName = "バック点"
    @State private var backsightX: Double = 100
    @State private var backsightY: Double = 0
    @StateObject private var backsightLocationManager = LocationManager()

    // 視準点(複数、放射)
    @State private var sightPoints: [SightPoint] = [
        SightPoint(name: "視準点1"),
        SightPoint(name: "視準点2")
    ]

    private var stationCoord: PlaneCoordinate2D { PlaneCoordinate2D(x: stationX, y: stationY) }
    private var backsightCoord: PlaneCoordinate2D { PlaneCoordinate2D(x: backsightX, y: backsightY) }

    /// 器械点→バック点の方位角(後視方向角)。これが水平角0°の基準になる。
    private var backsightBearing: Double {
        GeoMath.distanceAndBearing(from: stationCoord, to: backsightCoord).bearing
    }

    private func computedCoordinate(for sight: SightPoint) -> PlaneCoordinate2D {
        var targetBearing = backsightBearing + sight.angle
        targetBearing = targetBearing.truncatingRemainder(dividingBy: 360)
        if targetBearing < 0 { targetBearing += 360 }
        return GeoMath.polarPoint(from: stationCoord, bearing: targetBearing, distance: sight.distance)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("平面直角座標系") {
                    ZonePickerView(zoneNumber: $zoneNumber)
                }

                Section("器械点(トータルステーションの設置点)") {
                    PointEntryCard(title: "点名", name: $stationName, x: $stationX, y: $stationY,
                                   zoneNumber: zoneNumber, locationManager: stationLocationManager)
                        .listRowInsets(EdgeInsets())
                        .padding(.vertical, 4)
                }

                Section("バック点(後視点。器械点から見た方向の基準)") {
                    PointEntryCard(title: "点名", name: $backsightName, x: $backsightX, y: $backsightY,
                                   zoneNumber: zoneNumber, locationManager: backsightLocationManager)
                        .listRowInsets(EdgeInsets())
                        .padding(.vertical, 4)

                    LabeledContent("後視方向角") {
                        Text(GeoMath.decimalToDMSString(backsightBearing))
                            .font(.subheadline.monospacedDigit())
                    }
                }

                Section("視準点(放射、複数追加できます)") {
                    ForEach($sightPoints) { $sight in
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("点名", text: $sight.name)
                                .font(.subheadline.bold())

                            HStack {
                                Text("水平角").frame(width: 56, alignment: .leading).foregroundStyle(.secondary)
                                TextField("後視からの角度", value: $sight.angle, format: .number.precision(.fractionLength(0...4)))
                                    .textFieldStyle(.roundedBorder)
                                Text("°")
                            }
                            CoordinateField(label: "距離", value: $sight.distance)

                            let result = computedCoordinate(for: sight)
                            HStack {
                                Text("→ X: \(result.x.m3)  Y: \(result.y.m3)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.blue)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { indexSet in
                        sightPoints.remove(atOffsets: indexSet)
                    }

                    Button {
                        sightPoints.append(SightPoint(name: "視準点\(sightPoints.count + 1)"))
                    } label: {
                        Label("視準点を追加", systemImage: "plus.circle")
                    }
                }
            }
            .navigationTitle("放射計算")
            .toolbar { EditButton() }
        }
    }
}

#Preview {
    RadialCalculationView()
}
