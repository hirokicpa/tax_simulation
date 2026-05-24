# frozen_string_literal: true

namespace :similar_industries do
  desc "類似業種比準価額データをCSVから取込（令和7年分）"
  task import: :environment do
    path = ENV.fetch("CSV_PATH", Rails.root.join("db/seed_data/similar_industries_r07.csv"))
    year = ENV.fetch("YEAR", SimilarIndustry::CURRENT_YEAR).to_i

    result = StockValuation::SimilarIndustryImporter.new(year: year).import_csv(path)
    print_result(result)
  end

  desc "国税庁 list_all.pdf から業種データを取込"
  task import_pdf: :environment do
    year = ENV.fetch("YEAR", SimilarIndustry::CURRENT_YEAR).to_i
    url = ENV.fetch("PDF_URL", StockValuation::NtaR07PdfCatalog::LIST_ALL_URL)

    puts "PDF取得中: #{url}"
    result = StockValuation::SimilarIndustryImporter.new(year: year).import_from_pdf(url)
    print_result(result)
  end

  desc "令和7年分を再取込（既存データ削除後、list_all + 分割PDF）"
  task reimport_r07: :environment do
    year = ENV.fetch("YEAR", SimilarIndustry::CURRENT_YEAR).to_i
    deleted = SimilarIndustry.where(year: year).delete_all
    puts "既存データ削除: #{deleted}件"

    importer = StockValuation::SimilarIndustryImporter.new(year: year)
    all_result = importer.import_nta_r07_list_all
    split_result = importer.import_nta_r07_split_pdfs

    count = SimilarIndustry.where(year: year).count
    missing_bcd = SimilarIndustry.where(year: year).where("profit_c = 0 OR net_asset_d = 0").count
    puts "取込後: #{count}件（配当・利益・簿価が未設定: #{missing_bcd}件）"
    print_result(
      StockValuation::SimilarIndustryImporter::Result.new(
        imported: all_result.imported + split_result.imported,
        skipped: all_result.skipped + split_result.skipped,
        errors: all_result.errors + split_result.errors
      )
    )
  end

  desc "国税庁 list_01〜15.pdf（分割版・推奨）から業種データを取込"
  task import_r07_pdfs: :environment do
    year = ENV.fetch("YEAR", SimilarIndustry::CURRENT_YEAR).to_i

    puts "国税庁 令和7年分 業種別PDFを順次取得します..."
    result = StockValuation::SimilarIndustryImporter.new(year: year).import_nta_r07_split_pdfs
    print_result(result)
  end

  desc "業種番号の重複・先頭ゼロを整理して並び順を正規化"
  task dedupe: :environment do
    year = ENV.fetch("YEAR", SimilarIndustry::CURRENT_YEAR).to_i
    SimilarIndustry.dedupe_for_year!(year)
    puts "整理完了: #{SimilarIndustry.where(year: year).count}件"
  end

  desc "類似業種比準価額データを国税庁HTMLから取込（実験的）"
  task import_html: :environment do
    year = ENV.fetch("YEAR", SimilarIndustry::CURRENT_YEAR).to_i
    url = ENV.fetch("SOURCE_URL", StockValuation::NtaR07PdfCatalog::INDEX_URL)

    result = StockValuation::SimilarIndustryImporter.new(year: year).import_from_html(url)
    print_result(result)
  end

  def print_result(result)
    puts "取込完了: #{result.imported}件"
    puts "スキップ: #{result.skipped}件"
    result.errors.first(20).each { |error| puts "エラー: #{error}" }
    puts "...(他 #{result.errors.size - 20} 件)" if result.errors.size > 20
  end
end
