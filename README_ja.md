# LidOnce

[English](README.md) | 日本語

LidOnceは、MacBookを閉じたまま一回だけ処理を継続するための、小さなネイティブ
macOSメニューバーアプリです。有効化して蓋を閉じると処理を継続し、次に蓋を開けた
時点で通常のスリープ動作へ自動的に戻します。

通常の`caffeinate`系ツールと異なり、閉蓋スリープを抑止するために必要なシステムの
`disablesleep`設定を制御します。

## 安全上の注意

MacBookを閉じた鞄の中で動作させると、発熱やバッテリー消費の危険があります。
LidOnceは目の届く作業に限って使用し、十分な放熱を確保してください。現在の版は、
開蓋時、時間制限到達時、手動OFF時、アプリ終了・異常終了時に通常のスリープ設定へ
戻します。バッテリー残量や温度による自動解除は、まだ実装していません。

## 必要環境

- macOS 13以降
- MacBook
- ソースからビルドするためのXcode Command Line Tools
- 制限付き権限を初回設定するための管理者アカウント

## ビルドとインストール

```sh
git clone https://github.com/hudikaha/lidonce.git
cd lidonce
make test
make install
./scripts/install-privilege.sh
open ~/Applications/LidOnce.app
```

次のファイルをインストールします。

- `~/Applications/LidOnce.app`
- `~/bin/lidonce`
- `/etc/sudoers.d/lidonce`

権限インストーラは、標準のmacOS管理者ダイアログを表示します。sudoersルールが
パスワードなしで許可するのは、次の2コマンドだけです。

```text
/usr/bin/pmset -a disablesleep 0
/usr/bin/pmset -a disablesleep 1
```

rootシェル全般や、制限のない`pmset`実行権限は与えません。

## 配布とGatekeeper

現在のソースビルドにはad-hocコード署名を使用しています。ローカルでビルドして動かす
だけなら、有料のApple Developer証明書は必要ありません。ただし、Developer ID署名や
Appleのnotarization（公証）は行っていません。

GitHub ReleasesやWebサイトから完成済みアプリを配布し、利用者が警告を回避する操作なしで
起動できるようにする標準的な方法は、Apple発行のDeveloper ID Application証明書で署名し、
hardened runtimeを有効にして、Appleのnotarizationへ提出することです。Developer ID証明書
の取得にはApple Developer Programへの加入が必要です。

信頼できる未確認・未公証アプリであれば、利用者が「システム設定 > プライバシーと
セキュリティ > このまま開く」で個別に許可することもできます。ただし、一般公開版で
Gatekeeperの回避操作を利用者へ要求するのは望ましくありません。現在のように配布先の
Macでソースからビルドすれば、ダウンロード済み完成アプリを配布物として実行する形には
なりません。

Homebrewで入る全実行ファイルにAppleのDeveloper ID署名があるわけではありません。
formulaのbottleは、レビュー済みメタデータ、チェックサム、ビルド来歴の仕組みで保護
されます。一方、公式Homebrew Caskで配布するGUIアプリは、利用者に回避操作を求めず
HomebrewのGatekeeper検査を通る必要があります。

参考資料: [Apple Developer ID](https://developer.apple.com/support/developer-id/)、
[Appleのnotarization要件](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)、
[Appleの「このまま開く」手順](https://support.apple.com/ja-jp/guide/mac-help/mh40616/mac)、
[Homebrewのサプライチェーン・セキュリティ](https://docs.brew.sh/Supply-Chain-Security)、
[Homebrew CaskのGatekeeper方針](https://docs.brew.sh/FAQ#why-was-a-cask-disabled-or-removed-after-a-macos-security-check)

## メニューバーでの操作

アイコンにプルダウンメニューはありません。直接クリックして操作します。

| 表示 | 意味 |
| --- | --- |
| `Zzz` | OFF。通常のスリープ動作 |
| `ON` | 時間制限なしで有効 |
| `ON 1`〜`ON 9` | 閉蓋後、最大N時間だけ有効 |

直前のクリックから0.5秒を超えてクリックするとOFFになります。`ON`または`ON N`の
表示中、0.5秒以内にもう一度クリックすると、時間制限が次のように進みます。

```text
ON → ON 1 → ON 2 → … → ON 9 → ON
```

OFFのときにクリックすると、最後に選んだ時間制限で再び有効になります。アプリ起動後の
初期値は時間制限なし（`ON`）です。

`ON N`の時間計測はアイコンのクリック時ではなく、実際に蓋を閉じた時点で始まります。
N時間後にも蓋が閉じていれば、LidOnceは`disablesleep 0`へ戻し、MacBookがスリープ
できる状態にします。それより前に蓋を開いた場合も、直ちに通常の設定へ戻します。

## コマンドライン

コマンドの大文字・小文字は区別しません。CLIは起動中のアプリへ要求を送り、GUIと同じ
状態機械と安全動作を使用します。

```sh
lidonce on       # 時間制限なし。ONと同じ
lidonce on1      # 閉蓋後、最大1時間
lidonce on2      # 閉蓋後、最大2時間。on3〜on9も指定可能
lidonce off      # 直ちに解除して通常のスリープへ戻す
lidonce status   # 現在の状態を表示
lidonce open     # メニューバーアプリを起動
```

`lidonce on`、`on1`〜`on9`は、必要ならアプリを自動的に起動します。`status`の出力例は
次の通りです。

```text
off
armed
armed 2
closed
closed 2
```

`armed`は有効化済みで閉蓋待ち、`closed`は閉蓋を検出済みという意味です。末尾の数字は
時間制限で、数字なしは時間制限なしです。

## 状態遷移と異常時の復旧

中心となる状態機械は次の通りです。

```text
OFF → ARMED → CLOSED → OFF
```

- `OFF → ARMED`: ユーザーが有効化し、`disablesleep 1`が成功
- `ARMED → CLOSED`: 閉蓋を検出。時間制限付きならここから計測開始
- `CLOSED → OFF`: 開蓋または時間制限到達
- `ARMED/CLOSED → OFF`: ユーザーが手動でOFF

有効中は独立した監視プロセスがアプリを監視します。アプリが終了・異常終了すると、
監視プロセスが限定的に許可された`disablesleep 0`を実行します。一時的に蓋センサーを
読めなかった場合は、電源設定を変更しません。

## macOS 26でメニューバー項目が見えない場合

macOS 26では、メニューバーの表示枠が足りないと、システム設定で許可され、AppKit上も
表示中と判定されている第三者アプリの項目が隠れることがあります。「システム設定 >
メニューバー」で「天気」など不要な標準項目をオフにして表示枠を空けてください。
LidOnceやほかの第三者項目が表示されるようになります。

## 開発

```sh
make test    # 状態機械とクリック選択のテスト
make build   # build/LidOnce.appとbuild/lidonceを生成
make install # 現在のソース版をこのユーザー用にインストール
make clean
```

アプリとCLIは次のディレクトリにあるファイルを介して通信します。

```text
~/Library/Application Support/LidOnce/
```

## アンインストール

最初にLidOnceをOFFにしてから、アプリ、CLI、制限付きsudoersルールを削除します。

```sh
~/bin/lidonce off
pkill -x LidOnce
rm -rf ~/Applications/LidOnce.app
rm -f ~/bin/lidonce
sudo rm -f /etc/sudoers.d/lidonce
rm -rf ~/Library/Application\ Support/LidOnce
```

## ライセンス

[MIT](LICENSE)
