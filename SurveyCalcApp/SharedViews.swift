import SwiftUI
import CoreLocation

/// 平面直角座標系(1〜19系)の選択ピッカー
struct ZonePickerView: View {
    @Binding var zoneNumber: Int

    var body: some View {
        Picker("系番号", selection: $zoneNumber) {
            ForEach(ZoneOrigin.all) { zone in
                Text(zone.name).tag(zone.number)
            }
        }
    }
}

/// 数値入力用のラベル付きテキストフィールド(m単位)
struct CoordinateField: View {
    let label: String
    @Binding var value: Double

    var body: some View {
        HStack {
            Text(label)
                .frame(width: 28, alignment: .leading)
                .foregroundStyle(.secondary)
            TextField("0.000", value: $value, format: .number.precision(.fractionLength(0...4)))
                .keyboardType(.numbersAndPunctuation)
                .textFieldStyle(.roundedBorder)
            Text("m")
                .foregroundStyle(.secondary)
        }
    }
}

/// 1点分の入力カード。X,Y手入力、またはGPSで現在地を取得して
/// 選択中の系で平面直角座標に変換した値を反映する。
struct PointEntryCard: View {
    let title: String
    @Binding var name: String
    @Binding var x: Double
    @Binding var y: Double
    let zoneNumber: Int
    @ObservedObject var locationManager: LocationManager

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                TextField(title, text: $name)
                    .font(.headline)
                Spacer()
                Button {
                    locationManager.requestLocation()
                } label: {
                    if locationManager.isAcquiring {
                        ProgressView()
                    } else {
                        Label("現在地", systemImage: "location.fill")
                    }
                }
                .buttonStyle(.bordered)
            }

            CoordinateField(label: "X", value: $x)
            CoordinateField(label: "Y", value: $y)

            if let error = locationManager.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onChange(of: locationManager.currentFix) { _, newFix in
            guard let fix = newFix else { return }
            let zone = ZoneOrigin.zone(for: zoneNumber)
            let xy = GeoMath.blToXY(lat: fix.latitude, lon: fix.longitude, zone: zone)
            x = xy.x
            y = xy.y
        }
    }
}

extension Double {
    /// 表示用に丸めた文字列(小数点以下3桁)
    var m3: String { String(format: "%.3f", self) }
}
