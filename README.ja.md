# Nekketsu — MiSTer 版 熱血高校ドッジボール部

[English](README.md) · [한국어](README.ko.md) · 日本語

テクノスジャパンが 1987 年に発売したアーケードゲーム **熱血高校ドッジボール部 / Super Dodge Ball** の MiSTer FPGA コアです。

趣味のプロジェクトで、**jotego 氏の公式コアではありません。** jotego 氏の JTFRAME フレームワークの上に作り、同氏の熱血硬派くにおくん（海外版：レネゲード）とダブルドラゴンのコアから多くを借りています。

## AI を使った開発

このコアは AI コーディングアシスタント（Claude Code 経由で Anthropic の Claude）の助けを借りて開発しました。

## 対応ゲーム

| MAME セット | タイトル | MRA |
|---|---|---|
| `nkdodge` | 熱血高校ドッジボール部（日本版） | `mra/Nekketsu Koukou Dodgeball Bu (Japan).mra` |
| `spdodgeb` | Super Dodge Ball（米国版） | `mra/Super Dodge Ball (US).mra` |

海賊版（ブートレグ）の `nkdodgeb` には対応していません。ROM は含まれていないので、お手持ちの MAME セット（`nkdodge.zip`、`spdodgeb.zip`）を `games/mame/` に置いてください。

## 目標：実機（PCB）のように動くこと

エミュレーターをまねるのではなく、オリジナル基板と同じように動くことを目指しています。資料どうしで食い違うときは、次の優先順位で判断します。

1. オリジナル基板（実機の録画映像）。
2. 同じ世代のテクノス兄弟基板の回路図。主に [jtcores](https://github.com/jotego/jtcores) に描き直されている熱血硬派くにおくん（TA-0018）の回路図（`cores/kunio/sch`）です。
3. MAME の `technos/spdodgeb.cpp` ドライバー。ゲームのプログラムから見える部分（メモリマップ、入出力、MCU）は信頼し、映像タイミングは参考程度に使います。

熱血高校ドッジボール部の基板（TA-0022）の回路図は、公開されたものは見つかっていません。

## ハードウェア

| 項目 | チップ | 実装 |
|---|---|---|
| メイン CPU | 6502 @ 2MHz | `jt65c02` |
| サウンド CPU | HD68A09P | `jtframe_sys6809` 経由の `mc6809i` |
| MCU（入力処理、プロテクト） | HD63701Y0 @ 4MHz（クロック未確認） | ダンプされた ROM を動かす `jt63701y` |
| FM | YM3812 | `jtopl2` |
| ADPCM | MSM5205 × 2 | `jt5205` |
| 映像 | ピクセルクロック 6MHz、全体 384 × 272、表示 240 × 237 | `jtframe_vtimer`、`jtframe_scroll`、独自のスプライトエンジン |
| 色 | カラー PROM 2 個、RGB 各 4 ビット | 独自のカラーミキサー |

## 現在の状態

動いているもの：

- 両セットとも起動し、MCU のチェックを通ってプレイできます。
- 音楽、効果音、音声。
- 背景、スプライト、色。映像タイミングは兄弟基板 Renegade のラインカウンタに従います。表示は実機と同じ 240 × 237（MAME は 9 ライン上、8 ドット左から 256 × 240 を表示）で、スコア表示の下の境目はゲーム自身の IRQ タイミングで決まります。両方が表示するラインでは、デモ画面は MAME とピクセル単位で一致し、違うのはスコア表示のすぐ下の 1 ラインだけです（MAME はそのラインをスコア表示のスクロールで描きます）。
- レバー 2 回入れでダッシュ（MCU の入力処理）。
- ポーズ（JTFRAME、`P` キー）。

既知の問題：

- プレイ中、コートがスクロールするときにスプライトがちらつくことがあります。実機ではスプライトと背景が一緒に動きます。
- 2 人プレイ、DIP スイッチ、リセットはまだ確認していません。
- 画面反転とテーブル筐体モードには対応していません。

## 操作

8 方向レバーとボタン 2 個を使います。

| 入力 | 動作 |
|---|---|
| ボタン 1 | シュート |
| ボタン 2 | パス |
| 両ボタン同時押し | ジャンプ |
| レバーを同じ方向に素早く 2 回入れる | ダッシュ |

DIP スイッチ（初期値は MRA に入っていて、OSD で変更できます）：Coin A、Coin B、Demo Sounds、Difficulty、Allow Continue。画面反転（Flip Screen）は設定項目に含めていません。

## ビルド

[BUILD.md](BUILD.md) を参照してください。このコアは [jtcores](https://github.com/jotego/jtcores) を取得したフォルダーの中で、jotego 氏の `jtcore` ツールを使ってビルドします。

## クレジットと謝辞

- **Jose Tejada (jotego) 氏**：JTFRAME と、このコアの元になったコアとモジュール（jtkunio（くにおくん）、jtdd（ダブルドラゴン）、`jt65c02`、`jt63701y`、`jtopl`、`jt5205`、`jtframe_scroll`）、そしてくにおくんの回路図。https://github.com/jotego/jtcores
- **Alexey Melnikov (sorgelig) 氏と MiSTer プロジェクト**：JTFRAME が使っている MiSTer フレームワーク（`sys/`）。
- **MAME**：Paul Hampson 氏と Nicola Salmoria 氏による `spdodgeb` ドライバー。参考資料としてのみ使いました（MAME のコードは含まれていません）。
- **テクノスジャパン**：原作のゲーム。

## ライセンス

GPLv3 です。[LICENSE](LICENSE) を参照してください。jtcores から取り入れた部分は、元の GPLv3 ライセンスと著作権表示をそのまま残しています。
