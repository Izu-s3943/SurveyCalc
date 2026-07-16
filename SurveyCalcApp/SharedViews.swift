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
            .onChange(of: text) { _, newText in
                // 入力中でも、解釈できる数値であれば即座に計算用の値を更新する。
                // (表示上の文字列と、実際に計算に使われる値がズレるのを防ぐため)
                if let parsed = parse(newText) {
                    value = parsed
                }
            }
            .onChange(of: isFocused) { _, focused in
                if !focused {
                    // フォーカスが外れたら、表示だけをきれいな形式に整える
                    text = format(value)
                }
            }
            .onChange(of: value) { _, newValue in
                // GPS取得などアプリ側からの更新は、編集中でなければ表示に反映する
                if !isFocused { text = format(newValue) }
            }
    }

    private func parse(_ raw: String) -> Double? {
        let normalized = raw
            .replacingOccurrences(of: "。", with: ".")
            .replacingOccurrences(of: "、", with: ".")
            .replacingOccurrences(of: "ー", with: "-")
            .replacingOccurrences(of: "−", with: "-")
            .trimmingCharacters(in: .whitespaces)
        return Double(normalized)
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
    /// 表示用に丸めた文字列(小数点以下3桁、座標・面積など)
    var m3: String { String(format: "%.3f", self) }
    /// 距離表示用(小数点以下4桁。現場で切り捨て/四捨五入を使い分けられるように4桁目まで見せる)
    var m4: String { String(format: "%.4f", self) }
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

    /// 画面右上に「クリア」ボタンを表示し、タップすると確認のうえ入力内容をリセットする。
    /// 前回の計算結果を見たまま、次の測点を入力してしまう入力ミスを防ぐため。
    func withClearButton(onClear: @escaping () -> Void) -> some View {
        modifier(ClearButtonModifier(onClear: onClear))
    }
}

private struct ClearButtonModifier: ViewModifier {
    let onClear: () -> Void
    @State private var showConfirm = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(role: .destructive) {
                        showConfirm = true
                    } label: {
                        Label("クリア", systemImage: "trash")
                    }
                }
            }
            .alert("入力内容をクリアしますか?", isPresented: $showConfirm) {
                Button("クリア", role: .destructive, action: onClear)
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("この画面のすべての入力値が初期状態に戻ります。")
            }
    }
}
