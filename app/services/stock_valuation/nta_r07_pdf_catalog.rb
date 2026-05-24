# frozen_string_literal: true

module StockValuation
  # 令和7年6月9日公表（r07/2506）の業種別PDF一覧
  module NtaR07PdfCatalog
    BASE = "https://www.nta.go.jp/law/tsutatsu/kobetsu/hyoka/r07/2506/pdf".freeze
    LIST_ALL_URL = "#{BASE}/list_all.pdf".freeze
    INDEX_URL = "https://www.nta.go.jp/law/tsutatsu/kobetsu/hyoka/r07/2506/index.htm".freeze

    # list_XX.pdf と大分類名
    SPLIT_PDFS = {
      "01" => { major: "建設業", url: "#{BASE}/list_01.pdf" },
      "02" => { major: "製造業", middle: "食料品・飲料・たばこ・飼料", url: "#{BASE}/list_02.pdf" },
      "03" => { major: "製造業", middle: "繊維工業・パルプ・紙・印刷", url: "#{BASE}/list_03.pdf" },
      "04" => { major: "製造業", middle: "化学・石油・ゴム・プラスチック", url: "#{BASE}/list_04.pdf" },
      "05" => { major: "製造業", middle: "窯業・土石・金属・機械", url: "#{BASE}/list_05.pdf" },
      "06" => { major: "製造業", middle: "電気機械・輸送用機械・その他製造", url: "#{BASE}/list_06.pdf" },
      "07" => { major: "電気・ガス・熱供給・水道業、情報通信業", url: "#{BASE}/list_07.pdf" },
      "08" => { major: "運輸業、郵便業", url: "#{BASE}/list_08.pdf" },
      "09" => { major: "卸売業", middle: "各種商品・機械・食品等", url: "#{BASE}/list_09.pdf" },
      "10" => { major: "卸売業", middle: "その他卸売業", url: "#{BASE}/list_10.pdf" },
      "11" => { major: "小売業", url: "#{BASE}/list_11.pdf" },
      "12" => { major: "金融業、保険業、不動産業、物品賃貸業", url: "#{BASE}/list_12.pdf" },
      "13" => { major: "学術研究・専門・技術サービス業", url: "#{BASE}/list_13.pdf" },
      "14" => { major: "宿泊業、飲食サービス業", url: "#{BASE}/list_14.pdf" },
      "15" => { major: "生活関連サービス業、娯楽業、教育・医療・サービス業等", url: "#{BASE}/list_15.pdf" }
    }.freeze
  end
end
