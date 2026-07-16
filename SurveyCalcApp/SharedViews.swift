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
    /// true にすると「38-42-38.5」のような 度-分-秒 のハイフン区切り入力を受け付け、
    /// 表示もその形式で行う(角度専用)。
    var allowDMSInput: Bool = false

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
        var normalized = raw
            .replacingOccurrences(of: "。", with: ".")
            .replacingOccurrences(of: "、", with: ".")
            .replacingOccurrences(of: "ー", with: "-")
            .replacingOccurrences(of: "−", with: "-")
            .trimmingCharacters(in: .whitespaces)

        guard !normalized.isEmpty else { return nil }

        guard allowDMSInput else {
            return Double(normalized)
        }

        // 度-分-秒 形式(例: 38-42-38.5、または 38-42)を10進度に変換する。
        // 先頭の "-" は負号として扱い、区切りの "-" とは区別する。
        var isNegative = false
        if normalized.hasPrefix("-") {
            isNegative = true
            normalized.removeFirst()
        }

        if normalized.contains("-") {
            let parts = normalized.split(separator: "-", omittingEmptySubsequences: false).map(String.init)
            if parts.count == 3,
               let d = Double(parts[0]), let m = Double(parts[1]), let s = Double(parts[2]) {
                let decimal = GeoMath.dmsToDecimal(degrees: d, minutes: m, seconds: s)
                return isNegative ? -decimal : decimal
            }
            if parts.count == 2,
               let d = Double(parts[0]), let m = Double(parts[1]) {
                let decimal = GeoMath.dmsToDecimal(degrees: d, minutes: m, seconds: 0)
                return isNegative ? -decimal : decimal
            }
            return nil // 途中入力(例: "38-")はまだ確定させない
        }

        let plain = Double(normalized)
        return plain.map { isNegative ? -$0 : $0 }
    }

    private func format(_ v: Double) -> String {
        if allowDMSInput {
            return Self.dmsDashString(v)
        }
        var s = String(format: "%.\(decimals)f", v)
        while s.contains(".") && s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s
    }

    /// 10進度 → "38-42-38.50" のようなハイフン区切り文字列に変換
    private static func dmsDashString(_ decimal: Double) -> String {
        let sign = decimal < 0 ? "-" : ""
        let absVal = abs(decimal)
        let deg = Int(absVal)
        let minFull = (absVal - Double(deg)) * 60
        let minutes = Int(minFull)
        let seconds = (minFull - Double(minutes)) * 60
        return String(format: "%@%d-%d-%05.2f", sign, deg, minutes, seconds)
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
                    x = 0
                    y = 0
                } label: {
                    Image(systemName: "xmark.circle")
                }
                .buttonStyle(.bordered)
                .tint(.secondary)

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
