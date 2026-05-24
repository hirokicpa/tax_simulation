# 非上場株式評価シミュレーション（類似業種比準・会社規模判定）

## 概要

国税庁の「取引相場のない株式の評価明細書」および令和7年分「類似業種比準価額計算上の業種目及び業種目別株価等」に基づき、以下を概算します。

- 会社規模判定（第1表の2）
- 類似業種比準価額（第4表）

## セットアップ

```bash
bundle install
rails db:migrate
# 国税庁PDFから取込（推奨: 再取込タスク）
rails similar_industries:reimport_r07
# または分割PDFのみ
rails similar_industries:import_r07_pdfs
# または list_all.pdf 一括
rails similar_industries:import_pdf
# または同梱CSV
rails similar_industries:import
rails server
```

ブラウザで `/simulations/stock_valuation` にアクセスします。

## 類似業種データの取込

### 国税庁PDF取込（セレクトボックス用データ）

```bash
# 推奨: 既存データを削除してから list_all + 分割PDF で再取込
rails similar_industries:reimport_r07

# 分割PDFのみ
rails similar_industries:import_r07_pdfs

# list_all.pdf 一括
rails similar_industries:import_pdf
# 別URLを指定する場合
PDF_URL=https://www.nta.go.jp/law/tsutatsu/kobetsu/hyoka/r07/2506/pdf/list_all.pdf rails similar_industries:import_pdf
```

参考: [業種目別株価等一覧（令和7年分）](https://www.nta.go.jp/law/tsutatsu/kobetsu/hyoka/r07/2506/index.htm)

### CSV取込

```bash
rails similar_industries:import
# 別CSVを使う場合
CSV_PATH=db/seed_data/your_file.csv rails similar_industries:import
```

### HTML取込（実験的）

```bash
rails similar_industries:import_html
```

HTMLの構造変更により失敗する場合は CSV 取込を利用してください。

## 入力単位

- 金額: **円**（カンマ区切り可）
- 発行済株式総数: **株**
- 従業員数: **人**

## 参考URL

- https://www.nta.go.jp/law/tsutatsu/kobetsu/hyoka/r07/2506/index.htm
- https://www.nta.go.jp/taxes/shiraberu/taxanswer/hyoka/4638.htm

## 注意

本ツールは概算です。実際の申告・評価では、株主区分、特定会社の該当性等の追加判定が必要です。
