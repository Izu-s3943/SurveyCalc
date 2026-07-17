import Foundation

/// 測量計算コアロジック
/// 緯度経度 ⇔ 平面直角座標の変換は、国土地理院が公開する
/// 河瀬和重(2011)「Gauss-Krüger投影における経緯度座標及び平面直角座標
/// 相互間の座標換算についてのより簡明な計算方法」(国土地理院時報121号)
/// に基づくアルゴリズム(GRS80楕円体、5次までの級数展開)を実装している。
enum GeoMath {

    // MARK: - 準拠楕円体(GRS80)パラメータ
    private static let a: Double = 6378137.0            // 長半径(m)
    private static let F: Double = 298.257222101         // 逆扁平率
    private static let m0: Double = 0.9999                // 座標系原点の縮尺係数

    private static var n: Double { 1.0 / (2.0 * F - 1.0) }

    private static func degToRad(_ deg: Double) -> Double { deg * .pi / 180.0 }
    private static func radToDeg(_ rad: Double) -> Double { rad * 180.0 / .pi }

    // MARK: - 緯度経度 → 平面直角座標
    static func blToXY(lat: Double, lon: Double, zone: ZoneOrigin) -> PlaneCoordinate2D {
        let phi = degToRad(lat)
        let lambda = degToRad(lon)
        let phi0 = degToRad(zone.originLat)
        let lambda0 = degToRad(zone.originLon)
        let nn = n

        let A0 = 1 + pow(nn, 2) / 4 + pow(nn, 4) / 64
        let A1 = -(3.0 / 2.0) * (nn - pow(nn, 3) / 8 - pow(nn, 5) / 64)
        let A2 = (15.0 / 16.0) * (pow(nn, 2) - pow(nn, 4) / 4)
        let A3 = -(35.0 / 48.0) * (pow(nn, 3) - (5.0 / 16.0) * pow(nn, 5))
        let A4 = (315.0 / 512.0) * pow(nn, 4)
        let A5 = -(693.0 / 1280.0) * pow(nn, 5)
        let A = [A0, A1, A2, A3, A4, A5]

        let a1 = (1.0/2.0)*nn - (2.0/3.0)*pow(nn,2) + (5.0/16.0)*pow(nn,3) + (41.0/180.0)*pow(nn,4) - (127.0/288.0)*pow(nn,5)
        let a2 = (13.0/48.0)*pow(nn,2) - (3.0/5.0)*pow(nn,3) + (557.0/1440.0)*pow(nn,4) + (281.0/630.0)*pow(nn,5)
        let a3 = (61.0/240.0)*pow(nn,3) - (103.0/140.0)*pow(nn,4) + (15061.0/26880.0)*pow(nn,5)
        let a4 = (49561.0/161280.0)*pow(nn,4) - (179.0/168.0)*pow(nn,5)
        let a5 = (34729.0/80640.0)*pow(nn,5)
        let alpha = [0, a1, a2, a3, a4, a5] // index 0 は未使用

        let k = 2.0 * sqrt(nn) / (1.0 + nn)
        let t = sinh(atanh(sin(phi)) - k * atanh(k * sin(phi)))
        let tb = sqrt(1 + t * t)
        let lambdaC = cos(lambda - lambda0)
        let lambdaS = sin(lambda - lambda0)
        let xiPrime = atan2(t, lambdaC)
        let etaPrime = atanh(lambdaS / tb)

        var sPhi0 = A[0] * phi0
        for j in 1...5 {
            sPhi0 += A[j] * sin(2.0 * Double(j) * phi0)
        }
        sPhi0 *= (m0 * a / (1 + nn))

        let ab = m0 * a * A[0] / (1 + nn)

        var xSum = xiPrime
        var ySum = etaPrime
        for j in 1...5 {
            let jd = Double(j)
            xSum += alpha[j] * sin(2*jd*xiPrime) * cosh(2*jd*etaPrime)
            ySum += alpha[j] * cos(2*jd*xiPrime) * sinh(2*jd*etaPrime)
        }

        return PlaneCoordinate2D(x: ab * xSum - sPhi0, y: ab * ySum)
    }

    // MARK: - 平面直角座標 → 緯度経度(ニュートン法による逆変換)
    static func xyToBL(x: Double, y: Double, zone: ZoneOrigin) -> GeodeticCoordinate {
        var lat = zone.originLat
        var lon = zone.originLon
        let tolerance = 1e-9      // メートル
        let delta = 1e-6          // 数値微分用の微小角(度)

        for _ in 0..<30 {
            let f = blToXY(lat: lat, lon: lon, zone: zone)
            let fx = f.x - x
            let fy = f.y - y
            if abs(fx) < tolerance && abs(fy) < tolerance { break }

            let fLat = blToXY(lat: lat + delta, lon: lon, zone: zone)
            let fLon = blToXY(lat: lat, lon: lon + delta, zone: zone)

            let dXdLat = (fLat.x - f.x) / delta
            let dYdLat = (fLat.y - f.y) / delta
            let dXdLon = (fLon.x - f.x) / delta
            let dYdLon = (fLon.y - f.y) / delta

            let det = dXdLat * dYdLon - dXdLon * dYdLat
            if abs(det) < 1e-20 { break }

            let dLat = (dYdLon * fx - dXdLon * fy) / det
            let dLon = (dXdLat * fy - dYdLat * fx) / det

            lat -= dLat
            lon -= dLon
        }

        return GeodeticCoordinate(latitude: lat, longitude: lon)
    }

    // MARK: - 2点間の距離と方位角
    /// 戻り値: 距離[m]、方位角[度](真北0°、時計回り0〜360°)
    static func distanceAndBearing(from p1: PlaneCoordinate2D, to p2: PlaneCoordinate2D) -> (distance: Double, bearing: Double) {
        let dx = p2.x - p1.x // 北方向差
        let dy = p2.y - p1.y // 東方向差
        let distance = sqrt(dx*dx + dy*dy)
        var bearing = radToDeg(atan2(dy, dx))
        if bearing < 0 { bearing += 360 }
        return (distance, bearing)
    }

    // MARK: - 多角形面積(座標法/シューレース公式)
    static func polygonArea(points: [PlaneCoordinate2D]) -> Double {
        guard points.count >= 3 else { return 0 }
        var sum = 0.0
        let n = points.count
        for i in 0..<n {
            let p1 = points[i]
            let p2 = points[(i + 1) % n]
            sum += p1.x * p2.y - p2.x * p1.y
        }
        return abs(sum) / 2.0
    }

    // MARK: - 放射法(器械点・バック点から視準点の座標を求める)
    /// 器械点から、指定した方位角(バック点方向を基準とした角度を加算済みのもの)・距離にある点の座標を求める。
    /// いわゆる「順計算」(トラバースの直接計算)。
    static func radiationPoint(station: PlaneCoordinate2D, azimuth: Double, distance: Double) -> PlaneCoordinate2D {
        let rad = degToRad(azimuth)
        return PlaneCoordinate2D(x: station.x + distance * cos(rad), y: station.y + distance * sin(rad))
    }

    // MARK: - 交点計算1: 前方交会(2点からの方向角による交点)
    /// p1から方位角bearing1、p2から方位角bearing2の「前方」に伸ばした視準方向(半直線)の交点を求める。
    /// 2直線が平行、または指定した方位角の前方では交わらない(反対方向でしか交わらない)場合は nil を返す。
    static func bearingIntersection(p1: PlaneCoordinate2D, bearing1: Double,
                                     p2: PlaneCoordinate2D, bearing2: Double) -> PlaneCoordinate2D? {
        let t1r = degToRad(bearing1), t2r = degToRad(bearing2)
        let d1x = cos(t1r), d1y = sin(t1r)
        let d2x = cos(t2r), d2y = sin(t2r)
        let det = d1x * (-d2y) - (-d2x) * d1y
        if abs(det) < 1e-12 { return nil }
        let bx = p2.x - p1.x
        let by = p2.y - p1.y
        let t1 = (bx * (-d2y) - (-d2x) * by) / det
        let t2 = (d1x * by - bx * d1y) / det
        // t1・t2 はそれぞれの点から交点までの「前方向への距離」に相当する。
        // マイナスは指定した方位角と反対方向でしか交わらないことを意味し、前方交会としては不成立。
        let tolerance = -1e-6
        guard t1 >= tolerance, t2 >= tolerance else { return nil }
        return PlaneCoordinate2D(x: p1.x + t1 * d1x, y: p1.y + t1 * d1y)
    }

    // MARK: - 交点計算2: 距離交会(2点からの距離による交点、円と円の交点)
    /// p1から距離d1、p2から距離d2の位置にある交点(通常2つ)を求める。
    /// 解が存在しない(2円が交わらない)場合は nil。
    static func distanceIntersection(p1: PlaneCoordinate2D, d1: Double,
                                      p2: PlaneCoordinate2D, d2: Double) -> (PlaneCoordinate2D, PlaneCoordinate2D)? {
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        let D = sqrt(dx * dx + dy * dy)
        guard D > 1e-9, D <= d1 + d2, D >= abs(d1 - d2) else { return nil }

        let a = (d1 * d1 - d2 * d2 + D * D) / (2 * D)
        let hSquared = d1 * d1 - a * a
        guard hSquared >= 0 else { return nil }
        let h = sqrt(hSquared)

        let xm = p1.x + a * dx / D
        let ym = p1.y + a * dy / D
        let rx = -dy * (h / D)
        let ry = dx * (h / D)

        return (PlaneCoordinate2D(x: xm + rx, y: ym + ry),
                PlaneCoordinate2D(x: xm - rx, y: ym - ry))
    }

    // MARK: - 交点計算3: 2直線の交点(各直線を2点で指定)
    static func lineIntersection(a1: PlaneCoordinate2D, a2: PlaneCoordinate2D,
                                  b1: PlaneCoordinate2D, b2: PlaneCoordinate2D) -> PlaneCoordinate2D? {
        let d1x = a2.x - a1.x, d1y = a2.y - a1.y
        let d2x = b2.x - b1.x, d2y = b2.y - b1.y
        let det = d1x * (-d2y) - (-d2x) * d1y
        if abs(det) < 1e-12 { return nil }
        let bx = b1.x - a1.x
        let by = b1.y - a1.y
        let t1 = (bx * (-d2y) - (-d2x) * by) / det
        return PlaneCoordinate2D(x: a1.x + t1 * d1x, y: a1.y + t1 * d1y)
    }

    // MARK: - 放射法: 起点+方位角+距離 から求点の座標を求める(トラバースの正算)
    /// distanceAndBearing() が「2点の座標から距離・方位角を求める」逆算にあたるのに対し、
    /// こちらは「起点・方位角・距離から新点の座標を求める」正算(順トラバース)にあたる。
    static func polarPoint(from origin: PlaneCoordinate2D, bearing: Double, distance: Double) -> PlaneCoordinate2D {
        let rad = degToRad(bearing)
        return PlaneCoordinate2D(x: origin.x + distance * cos(rad), y: origin.y + distance * sin(rad))
    }

    // MARK: - 度分秒 <-> 10進度
    static func dmsToDecimal(degrees: Double, minutes: Double, seconds: Double) -> Double {
        let sign: Double = degrees < 0 ? -1 : 1
        return sign * (abs(degrees) + minutes / 60.0 + seconds / 3600.0)
    }

    static func decimalToDMSString(_ decimal: Double) -> String {
        let sign = decimal < 0 ? "-" : ""
        let absVal = abs(decimal)
        let deg = Int(absVal)
        let minFull = (absVal - Double(deg)) * 60
        let minutes = Int(minFull)
        let seconds = (minFull - Double(minutes)) * 60
        return String(format: "%@%d°%02d'%05.2f\"", sign, deg, minutes, seconds)
    }
}
