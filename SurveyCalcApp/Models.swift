import Foundation

/// 平面直角座標(内部計算用)。X: 北方向(+)、Y: 東方向(+)、単位はメートル。
/// 国土地理院の定義に準拠(数学的なXYとは軸の意味が逆)。
struct PlaneCoordinate2D {
    var x: Double
    var y: Double
}

/// 緯度経度(度、10進法)。北緯・東経を正とする。
struct GeodeticCoordinate {
    var latitude: Double
    var longitude: Double
}

/// UI上で扱う「点」。名前付きの平面直角座標。
struct SurveyPoint: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var x: Double = 0   // 北方向 (m)
    var y: Double = 0   // 東方向 (m)

    var coordinate2D: PlaneCoordinate2D { PlaneCoordinate2D(x: x, y: y) }
}

/// 平面直角座標系の系番号ごとの原点(国土交通省告示第9号 平成14年に基づく)
struct ZoneOrigin: Identifiable, Hashable {
    let number: Int
    let name: String
    let originLat: Double  // 度
    let originLon: Double  // 度

    var id: Int { number }

    static let all: [ZoneOrigin] = [
        ZoneOrigin(number: 1,  name: "I系(長崎・鹿児島の一部)",                     originLat: 33.0, originLon: 129.0 + 30.0/60.0),
        ZoneOrigin(number: 2,  name: "II系(福岡・佐賀・熊本・大分・宮崎・鹿児島の一部)", originLat: 33.0, originLon: 131.0),
        ZoneOrigin(number: 3,  name: "III系(山口・島根・広島)",                     originLat: 36.0, originLon: 132.0 + 10.0/60.0),
        ZoneOrigin(number: 4,  name: "IV系(香川・愛媛・徳島・高知)",                 originLat: 33.0, originLon: 133.0 + 30.0/60.0),
        ZoneOrigin(number: 5,  name: "V系(兵庫・鳥取・岡山)",                       originLat: 36.0, originLon: 134.0 + 20.0/60.0),
        ZoneOrigin(number: 6,  name: "VI系(京都・大阪・福井・滋賀・三重・奈良・和歌山)", originLat: 36.0, originLon: 136.0),
        ZoneOrigin(number: 7,  name: "VII系(石川・富山・岐阜・愛知)",               originLat: 36.0, originLon: 137.0 + 10.0/60.0),
        ZoneOrigin(number: 8,  name: "VIII系(新潟・長野・山梨・静岡)",              originLat: 36.0, originLon: 138.0 + 30.0/60.0),
        ZoneOrigin(number: 9,  name: "IX系(東京・福島・栃木・茨城・埼玉・千葉・群馬・神奈川)", originLat: 36.0, originLon: 139.0 + 50.0/60.0),
        ZoneOrigin(number: 10, name: "X系(青森・秋田・山形・岩手・宮城)",            originLat: 40.0, originLon: 140.0 + 50.0/60.0),
        ZoneOrigin(number: 11, name: "XI系(北海道 小樽・函館周辺)",                 originLat: 44.0, originLon: 140.0 + 15.0/60.0),
        ZoneOrigin(number: 12, name: "XII系(北海道 札幌・旭川周辺)",                originLat: 44.0, originLon: 142.0 + 15.0/60.0),
        ZoneOrigin(number: 13, name: "XIII系(北海道 網走・釧路・根室周辺)",         originLat: 44.0, originLon: 144.0 + 15.0/60.0),
        ZoneOrigin(number: 14, name: "XIV系(東京都 小笠原諸島)",                    originLat: 26.0, originLon: 142.0),
        ZoneOrigin(number: 15, name: "XV系(沖縄本島周辺)",                          originLat: 26.0, originLon: 127.0 + 30.0/60.0),
        ZoneOrigin(number: 16, name: "XVI系(沖縄県 宮古・八重山)",                  originLat: 26.0, originLon: 124.0),
        ZoneOrigin(number: 17, name: "XVII系(沖縄県 大東諸島)",                     originLat: 26.0, originLon: 131.0),
        ZoneOrigin(number: 18, name: "XVIII系(東京都 沖ノ鳥島)",                    originLat: 20.0, originLon: 136.0),
        ZoneOrigin(number: 19, name: "XIX系(東京都 南鳥島)",                        originLat: 26.0, originLon: 154.0),
    ]

    static func zone(for number: Int) -> ZoneOrigin {
        all.first(where: { $0.number == number }) ?? all[8] // デフォルトIX系(関東)
    }
}
