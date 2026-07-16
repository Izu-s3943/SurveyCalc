import SwiftUI
import UIKit
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

/// 数値入力用の頑丈なテキストフィールド。
/// SwiftUIの `TextField(value:format:)` は、小数点以下を消して整数のまま
/// 確定しようとした際などに、内部の値が正しく更新されないことがある。
/// そのため文字列を経由して明示的にパースし、フォーカスが外れた時点で確定させる。
struct NumericTextField: View {
    @Binding var value: Double
    var placeholder: String = "0.000"
    var decimals: Int = 4

    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(.numbersAndPunctuation)
            .multilineTextAlignment(.trailing)
            .focused($isFocused)
            .onAppear { text = format(value) }
            .onChange(of: isFocused) { _, focused in
                if !focused { commit() }
            }
            .onChange(of: value) { _, newValue in
                // GPS取得などアプリ側からの更新は、編集中でなければ表示に反映する
                if !isFocused { text = format(newValue) }
            }
    }

    private func commit() {
        let normalized = text
            .replacingOccurrences(of: "。", with: ".")
            .replacingOccurrences(of: "、", with: ".")
            .replacingOccurrences(of: "ー", with: "-")
            .replacingOccurrences(of: "−", with: "-")
            .trimmingCharacters(in: .whitespaces)
        if let parsed = Double(normalized) {
            value = parsed
        }
        // 確定後は必ずフォーマット済みの表示に揃える(未入力・不正入力時は元の値に戻す)
        text = format(value)
    }

    private func format(_ v: Double) -> String {
        var s = String(format: "%.\(decimals)f", v)
        while s.contains(".") && s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s
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
            NumericTextField(value: $value)
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

extension View {
    /// キーボード表示中、キーボードのすぐ上に「閉じる」ボタンを表示する。
    /// タブバーがキーボードに隠れて他の画面へ切り替えられなくなる問題への対策。
    func withKeyboardDoneButton() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("閉じる") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
    }
}
