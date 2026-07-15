# 現場座標計算アプリ (SurveyCalc) — Mac不要ビルド手順

古いMacやXcodeが無くても、**GitHub Actions(クラウド上のMac)でビルドし、
Windowsパソコンから Sideloadly でiPhoneに直接インストール**できるように
構成しています。費用はかかりません(GitHubアカウントとApple IDのみ)。

## 全体の流れ

1. GitHubにこのフォルダをアップロードする
2. GitHub Actions(自動でクラウドMacが起動)がビルドし、`.ipa` ファイルを作る
3. `.ipa` をパソコンにダウンロードする
4. Windowsで **Sideloadly** を使い、無料のApple IDでiPhoneにインストールする
5. 7日ごとに手順4を繰り返す(無料Apple IDの制限)

---

## STEP 1: GitHubにアップロード

1. https://github.com でアカウントを作成(無料)
2. 右上の「+」→「New repository」
   - Repository name: `SurveyCalc`(任意)
   - Public を選択(Publicなら Actions の実行時間は無制限で無料)
   - 「Create repository」をクリック
3. 作成後の画面で「uploading an existing file」というリンクをクリック
4. このフォルダの中身**一式**(`project.yml`、`.github`フォルダ、`SurveyCalcApp`フォルダ)
   をまとめてドラッグ&ドロップ
   - ※ `.github` フォルダはブラウザからだと個別ドラッグが必要な場合があります。
     うまくいかない場合は「GitHub Desktop」アプリ(無料、Windows対応)を使うと
     フォルダごと簡単にアップロードできます
5. 「Commit changes」をクリック

## STEP 2: ビルドを実行する

1. リポジトリ画面上部の「Actions」タブを開く
2. 左側の「Build SurveyCalc IPA」をクリック
3. 「Run workflow」ボタン→再度「Run workflow」をクリック
4. 数分待つと、実行結果に緑のチェックマークがつく(失敗時は赤いバツ。ログを開いて
   エラー内容を確認してください)

## STEP 3: .ipaファイルをダウンロード

1. 緑のチェックがついた実行結果をクリック
2. ページ下部の「Artifacts」欄にある `SurveyCalc-ipa` をクリックしてダウンロード
3. ダウンロードされたzipを解凍すると `SurveyCalc.ipa` が出てきます

## STEP 4: WindowsでSideloadlyを使いiPhoneにインストール

1. iPhoneとWindowsパソコンをUSBケーブルで接続
2. 「Apple Devices」アプリ(Microsoft Store)または iTunes をインストールしておく
   (USB接続時にiPhoneを認識させるため)
3. https://sideloadly.io から Sideloadly をダウンロード・インストール
4. Sideloadlyを起動 → iPhoneが認識されていることを確認
5. `SurveyCalc.ipa` をSideloadlyの画面にドラッグ&ドロップ
6. Apple IDのメールアドレスを入力(無料のApple IDでOK)して「Start」
   - 2ファクタ認証を求められたらApple ID用の「App用パスワード」の作成が
     必要になる場合があります(Sideloadlyの案内に従ってください)
7. インストール完了後、iPhone側で **設定 → 一般 → VPNとデバイス管理** を開き、
   使用したApple IDのプロファイルをタップして「信頼」する
8. ホーム画面にSurveyCalcが表示されたら完了です

## 注意点(無料Apple IDの制限)

- インストールしたアプリは**7日間**で自動的に使えなくなります
  → 7日以内に、同じ `.ipa` を使って手順4を再実行してください(再ビルドは不要)
- 無料Apple IDでは、同時にインストールできる自作アプリの数に上限があります
  (目安として3つ程度)。他に自作アプリを入れている場合はご注意ください
- 位置情報の利用許可を初回起動時に聞かれるので「Appの使用中は許可」を選んでください

---

## アプリの内容

- **距離・方位角計算**: 2点の平面直角座標(X, Y)から距離と真北方位角を算出
- **座標変換**: 緯度経度 ⇔ 平面直角座標系(全19系対応)の相互変換
  (国土地理院公式の変換式、河瀬和重2011、GRS80楕円体に準拠)
- **面積計算**: 多角形の頂点座標から面積を算出(座標法、㎡・ha・坪表示)
- 各機能でGPSボタンから現在地を自動取得可能

⚠️ 境界確定・登記など法的効力を要する測量では、必ず国土地理院の測量計算サイトや
専用測量ソフトの結果と照合し、有資格者による検証を行ってください。本アプリは
現場での概算・検算用途を想定しています。

## ファイル構成

```
SurveyCalcRepo/
├── project.yml                  # XcodeGen用プロジェクト定義(自動でXcodeプロジェクトを生成)
├── .github/workflows/build.yml  # GitHub Actionsのビルド設定
└── SurveyCalcApp/
    ├── SurveyCalcApp.swift       # エントリーポイント
    ├── ContentView.swift         # タブ構成のメイン画面
    ├── Models.swift              # 座標・系原点のデータモデル
    ├── GeoMath.swift             # 座標変換・距離方位角・面積計算のロジック
    ├── LocationManager.swift     # GPS(CoreLocation)ラッパー
    ├── SharedViews.swift         # 系番号ピッカー・座標入力カードなど共通UI
    ├── DistanceBearingView.swift
    ├── CoordinateConversionView.swift
    └── AreaCalculationView.swift
```

## もしMacが手に入ったら

将来Xcodeが使える環境ができた場合は、`project.yml` を使わず、
`SurveyCalcApp` フォルダ内のファイルを普通にXcodeプロジェクトへ
ドラッグ&ドロップして取り込めば、そのまま同じアプリとして開発を続けられます。
