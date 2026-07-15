import SwiftUI

struct AreaCalculationView: View {
    @AppStorage("selectedZone") private var zoneNumber: Int = 9
    @StateObject private var locationManager = LocationManager()

    @State private var points: [SurveyPoint] = [
        SurveyPoint(name: "点1"),
        SurveyPoint(name: "点2"),
        SurveyPoint(name: "点3")
    ]
    @State private var activeIndex: Int? = nil

    private var area: Double {
        GeoMath.polygonArea(points: points.map { $0.coordinate2D })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("平面直角座標系") {
                    ZonePickerView(zoneNumber: $zoneNumber)
                }

                Section("多角形の頂点(順番に入力、3点以上)") {
                    ForEach($points) { $point in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                TextField("点名", text: $point.name)
                                    .font(.subheadline.bold())
                                Spacer()
                                Button {
                                    activeIndex = points.firstIndex(where: { $0.id == point.id })
                                    locationManager.requestLocation()
                                } label: {
                                    if locationManager.isAcquiring && activeIndex == points.firstIndex(where: { $0.id == point.id }) {
                                        ProgressView()
                                    } else {
                                        Image(systemName: "location.fill")
                                    }
                                }
                                .buttonStyle(.bordered)
                            }
                            CoordinateField(label: "X", value: $point.x)
                            CoordinateField(label: "Y", value: $point.y)
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { indexSet in
                        points.remove(atOffsets: indexSet)
                    }

                    Button {
                        points.append(SurveyPoint(name: "点\(points.count + 1)"))
                    } label: {
                        Label("頂点を追加", systemImage: "plus.circle")
                    }
                }

                Section("計算結果") {
                    if points.count < 3 {
                        Text("面積計算には3点以上の入力が必要です")
                            .foregroundStyle(.secondary)
                    } else {
                        LabeledContent("面積") {
                            Text("\(area.m3) m²")
                                .font(.title3.monospacedDigit())
                                .bold()
                        }
                        LabeledContent("参考: ヘクタール") {
                            Text("\((area / 10000).m3) ha")
                        }
                        LabeledContent("参考: 坪") {
                            Text("\((area / 3.30578).m3) 坪")
                        }
                    }
                }

                if let error = locationManager.errorMessage {
                    Section {
                        Text(error).font(.caption).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("面積計算")
            .toolbar { EditButton() }
            .onChange(of: locationManager.currentFix) { _, newFix in
                guard let fix = newFix, let idx = activeIndex, points.indices.contains(idx) else { return }
                let zone = ZoneOrigin.zone(for: zoneNumber)
                let xy = GeoMath.blToXY(lat: fix.latitude, lon: fix.longitude, zone: zone)
                points[idx].x = xy.x
                points[idx].y = xy.y
            }
        }
    }
}

#Preview {
    AreaCalculationView()
}
