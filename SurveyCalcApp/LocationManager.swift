import Foundation
import CoreLocation

/// GPSで取得した1回分の位置情報(SwiftUIのonChangeで比較できるようEquatable)
struct GPSFix: Equatable {
    var latitude: Double
    var longitude: Double
    var timestamp: Date
}

/// 現在地(緯度経度)をワンタップで取得するためのラッパー。
/// 各画面はこれを @StateObject として保持し、requestLocation() を呼ぶ。
final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    @Published var currentFix: GPSFix?
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var errorMessage: String?
    @Published var isAcquiring: Bool = false

    override init() {
        authorizationStatus = CLLocationManager().authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestLocation() {
        errorMessage = nil
        switch manager.authorizationStatus {
        case .notDetermined:
            isAcquiring = true
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            isAcquiring = true
            manager.requestLocation()
        case .denied, .restricted:
            errorMessage = "位置情報の利用が許可されていません。設定アプリで許可してください。"
        @unknown default:
            break
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        } else if authorizationStatus == .denied || authorizationStatus == .restricted {
            isAcquiring = false
            errorMessage = "位置情報の利用が許可されていません。設定アプリで許可してください。"
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        currentFix = GPSFix(latitude: loc.coordinate.latitude,
                             longitude: loc.coordinate.longitude,
                             timestamp: Date())
        isAcquiring = false
        errorMessage = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isAcquiring = false
        errorMessage = "位置情報の取得に失敗しました: \(error.localizedDescription)"
    }
}
