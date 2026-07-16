import SwiftUI

/// 視準点1件分の入力(順計算: 後視方向からの水平角と距離 → 座標を求める)
struct SightPoint: Identifiable {
    let id = UUID()
    var name: String
    var angle: Double = 0     // 後視方向からの水平角(度、時計回り)
    var distance: Double = 0  // 器械点からの水平距離(m)
}

struct RadialCalculationView: View {
    @AppStorage("selectedZone") private var zoneNumber: Int = 9

    enum CalcMode: String, CaseIterable, Identifiable {
        case forward = "順計算(角度・距離→座標)"
        case inverse = "逆計算(座標→角度・距離)"
        var id: String { rawValue }
    }
    @State private var calcMode: CalcMode = .forward

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

    // 順計算: 視準点(複数、放射)
    @State private var sightPoints: [SightPoint] = [
        SightPoint(name: "視準点1"),
        SightPoint(name: "視準点2")
    ]

    // 逆計算: 復元したい点(座標既知、複数)
    @State private var restorePoints: [SurveyPoint] = [
        SurveyPoint(name: "復元点1"),
        SurveyPoint(name: "復元点2")
    ]
    @State private var activeRestoreIndex: Int? = nil
    @StateObject private var restoreLocationManager = LocationManager()

    private var stationCoord: PlaneCoordinate2D { PlaneCoordinate2D(x: stationX, y: stationY) }
    private var backsightCoord: PlaneCoordinate2D { PlaneCoordinate2D(x: backsightX, y: backsightY) }

    /// 器械点→バック点の方位角。現場でバック点に0°をセットする基準になる。
    private var backsightBearing: Double {
        GeoMath.distanceAndBearing(from: stationCoord, to: backsightCoord).bearing
    }

    /// 順計算: 後視方向からの水平角+距離 → 座標
    private func computedCoordinate(for sight: SightPoint) -> PlaneCoordinate2D {
        var targetBearing = backsightBearing + sight.angle
        targetBearing = targetBearing.truncatingRemainder(dividingBy: 360)
        if targetBearing < 0 { targetBearing += 360 }
        return GeoMath.polarPoint(from: stationCoord, bearing: targetBearing, distance: sight.distance)
    }

    /// 逆計算: 座標 → 後視方向からの水平角+距離(現場でセットする値)
    private func angleAndDistance(to point: SurveyPoint) -> (angle: Double, distance: Double) {
        let result = GeoMath.distanceAndBearing(from: stationCoord, to: point.coordinate2D)
        var angle = result.bearing - backsightBearing
        angle = angle.truncatingRemainder(dividingBy: 360)
        if angle < 0 { angle += 360 }
        return (angle, result.distance)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("平面直角座標系") {
                    ZonePickerView(zoneNumber: $zoneNumber)
                }

                Section("計算方向") {
                    Picker("計算方向", selection: $calcMode) {
                        ForEach(CalcMode.allCases) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(calcMode == .forward
                         ? "後視方向を0°として、角度と距離を入力すると座標がわかります。"
                         : "探したい点の座標を入力すると、現場で器械にセットする角度と距離がわかります。バック点を見て0°をセットしてから使ってください。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("器械点(トータルステーションの設置点)") {
                    PointEntryCard(title: "点名", name: $stationName, x: $stationX, y: $stationY,
                                   zoneNumber: zoneNumber, locationManager: stationLocationManager)
                        .listRowInsets(EdgeInsets())
                        .padding(.vertical, 4)
                }

                Section("バック点(後視点。ここを見て角度0°をセットする基準)") {
                    PointEntryCard(title: "点名", name: $backsightName, x: $backsightX, y: $backsightY,
                                   zoneNumber: zoneNumber, locationManager: backsightLocationManager)
                        .listRowInsets(EdgeInsets())
                        .padding(.vertical, 4)

                    LabeledContent("後視方向角(参考、真北基準)") {
                        Text(GeoMath.decimalToDMSString(backsightBearing))
                            .font(.subheadline.monospacedDigit())
                    }
                }

                if calcMode == .forward {
                    forwardSection
                } else {
                    inverseSection
                }
            }
            .navigationTitle("放射計算")
            .toolbar { EditButton() }
            .withKeyboardDoneButton()
        }
    }

    // MARK: - 順計算セクション
    @ViewBuilder
    private var forwardSection: some View {
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
                    Text("→ X: \(result.x.m3)  Y: \(result.y.m3)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.blue)
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

    // MARK: - 逆計算セクション
    @ViewBuilder
    private var inverseSection: some View {
        Section("復元したい点(座標入力、複数追加できます)") {
            ForEach($restorePoints) { $point in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        TextField("点名", text: $point.name)
                            .font(.subheadline.bold())
                        Spacer()
                        Button {
                            activeRestoreIndex = restorePoints.firstIndex(where: { $0.id == point.id })
                            restoreLocationManager.requestLocation()
                        } label: {
                            Image(systemName: "location.fill")
                        }
                        .buttonStyle(.bordered)
                    }
                    CoordinateField(label: "X", value: $point.x)
                    CoordinateField(label: "Y", value: $point.y)

                    let result = angleAndDistance(to: point)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("→ 器械にセットする角度: \(GeoMath.decimalToDMSString(result.angle))")
                        Text("→ 距離: \(result.distance.m3) m")
                    }
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.blue)
                }
                .padding(.vertical, 4)
            }
            .onDelete { indexSet in
                restorePoints.remove(atOffsets: indexSet)
            }

            Button {
                restorePoints.append(SurveyPoint(name: "復元点\(restorePoints.count + 1)"))
            } label: {
                Label("復元点を追加", systemImage: "plus.circle")
            }

            if let error = restoreLocationManager.errorMessage {
                Text(error).font(.caption).foregroundStyle(.red)
            }
        }
        .onChange(of: restoreLocationManager.currentFix) { _, newFix in
            guard let fix = newFix, let idx = activeRestoreIndex, restorePoints.indices.contains(idx) else { return }
            let zone = ZoneOrigin.zone(for: zoneNumber)
            let xy = GeoMath.blToXY(lat: fix.latitude, lon: fix.longitude, zone: zone)
            restorePoints[idx].x = xy.x
            restorePoints[idx].y = xy.y
        }
    }
}

#Preview {
    RadialCalculationView()
}
