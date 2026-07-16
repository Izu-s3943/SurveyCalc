import SwiftUI

struct CoordinateConversionView: View {
    @AppStorage("selectedZone") private var zoneNumber: Int = 9
    @StateObject private var locationManager = LocationManager()

    enum Mode: String, CaseIterable, Identifiable {
        case blToXY = "緯度経度 → XY"
        case xyToBL = "XY → 緯度経度"
        var id: String { rawValue }
    }
    @State private var mode: Mode = .blToXY

    // 緯度経度入力(10進度)
    @State private var latitude: Double = 35.0
    @State private var longitude: Double = 139.0

    // 平面直角座標入力
    @State private var x: Double = 0
    @State private var y: Double = 0

    private var zone: ZoneOrigin { ZoneOrigin.zone(for: zoneNumber) }

    var body: some View {
        NavigationStack {
            Form {
                Section("平面直角座標系") {
                    ZonePickerView(zoneNumber: $zoneNumber)
                }

                Section("変換方向") {
                    Picker("変換方向", selection: $mode) {
                        ForEach(Mode.allCases) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if mode == .blToXY {
                    Section("入力: 緯度経度(10進法)") {
                        HStack {
                            Text("緯度").frame(width: 40, alignment: .leading)
                            NumericTextField(value: $latitude, placeholder: "35.000000", decimals: 8)
                        }
                        HStack {
                            Text("経度").frame(width: 40, alignment: .leading)
                            NumericTextField(value: $longitude, placeholder: "139.000000", decimals: 8)
                        }
                        Button {
                            locationManager.requestLocation()
                        } label: {
                            if locationManager.isAcquiring {
                                ProgressView()
                            } else {
                                Label("現在地を入力", systemImage: "location.fill")
                            }
                        }
                        if let error = locationManager.errorMessage {
                            Text(error).font(.caption).foregroundStyle(.red)
                        }
                    }

                    Section("変換結果: 平面直角座標(\(zone.name))") {
                        let xy = GeoMath.blToXY(lat: latitude, lon: longitude, zone: zone)
                        LabeledContent("X (北方向)") {
                            Text("\(xy.x.m3) m").font(.title3.monospacedDigit()).bold()
                        }
                        LabeledContent("Y (東方向)") {
                            Text("\(xy.y.m3) m").font(.title3.monospacedDigit()).bold()
                        }
                    }
                } else {
                    Section("入力: 平面直角座標(\(zone.name))") {
                        CoordinateField(label: "X", value: $x)
                        CoordinateField(label: "Y", value: $y)
                    }

                    Section("変換結果: 緯度経度") {
                        let bl = GeoMath.xyToBL(x: x, y: y, zone: zone)
                        LabeledContent("緯度") {
                            VStack(alignment: .trailing) {
                                Text("\(bl.latitude, specifier: "%.8f")°").monospacedDigit()
                                Text(GeoMath.decimalToDMSString(bl.latitude)).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        LabeledContent("経度") {
                            VStack(alignment: .trailing) {
                                Text("\(bl.longitude, specifier: "%.8f")°").monospacedDigit()
                                Text(GeoMath.decimalToDMSString(bl.longitude)).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("座標変換")
            .withKeyboardDoneButton()
            .withClearButton {
                latitude = 35.0; longitude = 139.0
                x = 0; y = 0
            }
            .onChange(of: locationManager.currentFix) { _, newFix in
                guard let fix = newFix else { return }
                latitude = fix.latitude
                longitude = fix.longitude
            }
        }
    }
}

#Preview {
    CoordinateConversionView()
}
