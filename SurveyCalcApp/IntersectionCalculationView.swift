import SwiftUI

struct IntersectionCalculationView: View {
    @AppStorage("selectedZone") private var zoneNumber: Int = 9

    enum Mode: String, CaseIterable, Identifiable {
        case bearing = "前方交会"
        case distance = "距離交会"
        case line = "2直線の交点"
        var id: String { rawValue }
    }
    @State private var mode: Mode = .bearing

    // 前方交会・距離交会で使う2つの既知点
    @State private var name1 = "既知点1"
    @State private var x1: Double = 0
    @State private var y1: Double = 0
    @State private var name2 = "既知点2"
    @State private var x2: Double = 100
    @State private var y2: Double = 0
    @StateObject private var loc1 = LocationManager()
    @StateObject private var loc2 = LocationManager()

    // 前方交会: 各点からの方位角
    @State private var bearing1: Double = 45
    @State private var bearing2: Double = 315

    // 距離交会: 各点からの距離
    @State private var dist1: Double = 100
    @State private var dist2: Double = 100

    // 2直線の交点: 直線1(A1,A2)、直線2(B1,B2)
    @State private var ax1: Double = 0
    @State private var ay1: Double = 0
    @State private var ax2: Double = 100
    @State private var ay2: Double = 100
    @State private var bx1: Double = 0
    @State private var by1: Double = 100
    @State private var bx2: Double = 100
    @State private var by2: Double = 0

    var body: some View {
        NavigationStack {
            Form {
                Section("平面直角座標系") {
                    ZonePickerView(zoneNumber: $zoneNumber)
                }

                Section("計算方法") {
                    Picker("計算方法", selection: $mode) {
                        ForEach(Mode.allCases) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(modeDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                switch mode {
                case .bearing:
                    bearingSections
                case .distance:
                    distanceSections
                case .line:
                    lineSections
                }
            }
            .navigationTitle("交点計算")
            .withKeyboardDoneButton()
        }
    }

    private var modeDescription: String {
        switch mode {
        case .bearing:
            return "2つの既知点から、それぞれ指定した方位角の方向に伸ばした直線の交点を求めます(前方交会法)。"
        case .distance:
            return "2つの既知点からの距離(斜距離や巻尺実測値など)をもとに交点を求めます。解は通常2つ出ます。"
        case .line:
            return "2点ずつで指定した2本の直線の交点を求めます。"
        }
    }

    // MARK: - 前方交会
    @ViewBuilder
    private var bearingSections: some View {
        Section("既知点1") {
            PointEntryCard(title: "点名", name: $name1, x: $x1, y: $y1, zoneNumber: zoneNumber, locationManager: loc1)
                .listRowInsets(EdgeInsets())
                .padding(.vertical, 4)
            HStack {
                Text("方位角").frame(width: 56, alignment: .leading).foregroundStyle(.secondary)
                NumericTextField(value: $bearing1, placeholder: "度", decimals: 4)
                Text("°")
            }
        }

        Section("既知点2") {
            PointEntryCard(title: "点名", name: $name2, x: $x2, y: $y2, zoneNumber: zoneNumber, locationManager: loc2)
                .listRowInsets(EdgeInsets())
                .padding(.vertical, 4)
            HStack {
                Text("方位角").frame(width: 56, alignment: .leading).foregroundStyle(.secondary)
                NumericTextField(value: $bearing2, placeholder: "度", decimals: 4)
                Text("°")
            }
        }

        Section("計算結果") {
            if let result = GeoMath.bearingIntersection(
                p1: PlaneCoordinate2D(x: x1, y: y1), bearing1: bearing1,
                p2: PlaneCoordinate2D(x: x2, y: y2), bearing2: bearing2
            ) {
                LabeledContent("X") { Text("\(result.x.m3) m").bold() }
                LabeledContent("Y") { Text("\(result.y.m3) m").bold() }
            } else {
                Text("2つの方向が平行のため、交点を求められません。方位角を見直してください。")
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - 距離交会
    @ViewBuilder
    private var distanceSections: some View {
        Section("既知点1") {
            PointEntryCard(title: "点名", name: $name1, x: $x1, y: $y1, zoneNumber: zoneNumber, locationManager: loc1)
                .listRowInsets(EdgeInsets())
                .padding(.vertical, 4)
            CoordinateField(label: "距離", value: $dist1)
        }

        Section("既知点2") {
            PointEntryCard(title: "点名", name: $name2, x: $x2, y: $y2, zoneNumber: zoneNumber, locationManager: loc2)
                .listRowInsets(EdgeInsets())
                .padding(.vertical, 4)
            CoordinateField(label: "距離", value: $dist2)
        }

        Section("計算結果(2つ求まります)") {
            if let (s1, s2) = GeoMath.distanceIntersection(
                p1: PlaneCoordinate2D(x: x1, y: y1), d1: dist1,
                p2: PlaneCoordinate2D(x: x2, y: y2), d2: dist2
            ) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("解1").font(.caption).foregroundStyle(.secondary)
                    LabeledContent("X") { Text("\(s1.x.m3) m").bold() }
                    LabeledContent("Y") { Text("\(s1.y.m3) m").bold() }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("解2").font(.caption).foregroundStyle(.secondary)
                    LabeledContent("X") { Text("\(s2.x.m3) m").bold() }
                    LabeledContent("Y") { Text("\(s2.y.m3) m").bold() }
                }
                Text("現場の実際の位置関係(進行方向の左右など)に合う方を採用してください。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("入力した距離では交点が求まりません(2円が交わらない位置関係です)。距離や座標を見直してください。")
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - 2直線の交点
    @ViewBuilder
    private var lineSections: some View {
        Section("直線1(2点で指定)") {
            CoordinateField(label: "X1", value: $ax1)
            CoordinateField(label: "Y1", value: $ay1)
            CoordinateField(label: "X2", value: $ax2)
            CoordinateField(label: "Y2", value: $ay2)
        }

        Section("直線2(2点で指定)") {
            CoordinateField(label: "X1", value: $bx1)
            CoordinateField(label: "Y1", value: $by1)
            CoordinateField(label: "X2", value: $bx2)
            CoordinateField(label: "Y2", value: $by2)
        }

        Section("計算結果") {
            if let result = GeoMath.lineIntersection(
                a1: PlaneCoordinate2D(x: ax1, y: ay1), a2: PlaneCoordinate2D(x: ax2, y: ay2),
                b1: PlaneCoordinate2D(x: bx1, y: by1), b2: PlaneCoordinate2D(x: bx2, y: by2)
            ) {
                LabeledContent("X") { Text("\(result.x.m3) m").bold() }
                LabeledContent("Y") { Text("\(result.y.m3) m").bold() }
            } else {
                Text("2直線が平行のため、交点を求められません。")
                    .foregroundStyle(.red)
            }
        }
    }
}

#Preview {
    IntersectionCalculationView()
}
