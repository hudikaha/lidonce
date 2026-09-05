# LidOnce

[English](README.md) | 日本語

LidOnceは、MacBookを閉じたまま一回だけ処理を継続するための、小さな
macOSメニューバーアプリです。有効化して蓋を閉じると処理を継続し、次に
蓋を開けた時点で通常のスリープ動作へ自動的に戻します。

状態遷移は意図的に単純にしています。

```text
OFF -> ARMED -> CLOSED -> OFF
```

通常の`caffeinate`系ツールと異なり、閉蓋スリープを抑止するために必要な
システムの`disablesleep`設定を制御します。明示的に有効化するまでは、この
設定を変更しません。

## 現在の状態

現時点では初期実装です。安全機構と実機試験が完了するまで、無人運用には
使用しないでください。

## 必要環境

- macOS 13以降
- Xcode Command Line Tools
- 蓋の開閉試験に使用するMacBook

## ビルドとテスト

```sh
make test
make build
```

`build/LidOnce.app`が生成されます。開発版は次の手順でインストールできます。

```sh
make install
./scripts/install-privilege.sh
open ~/Applications/LidOnce.app
```

権限インストーラが許可するのは、`disablesleep`を有効・無効にするための正確な
2つの`pmset`コマンドだけです。有効中にアプリが終了・異常終了した場合は、独立した
監視プロセスが通常のスリープ設定へ戻します。

メニューバーの **Enable next lid cycle**、または次のコマンドを使用できます。

```sh
lidonce on       # 次の閉蓋・開蓋の一往復を有効化
lidonce status   # off、armed、closedの状態表示
lidonce off      # 直ちに解除して通常のスリープへ戻す
lidonce open     # メニューバーアプリを起動
```

どちらもメニューバーアプリ内の同じ安全用状態機械を使用します。

### macOS 26でメニューバー項目が見えない場合

メニューバーの表示枠が足りないと、システム設定で許可されていても、macOSが
第三者アプリの項目を表示しないことがあります。「システム設定 > メニューバー」で
「天気」など不要な標準項目をオフにし、LidOnceの表示枠を空けてください。

## 安全上の注意

MacBookを閉じた鞄の中で動作させると、発熱やバッテリー消費の危険があります。
LidOnceは、処理を継続したまま短時間、目の届く範囲で移動する用途を想定します。
公開版では異常終了時の復旧と、バッテリー・温度による解除を実装します。

## ライセンス

[MIT](LICENSE)
