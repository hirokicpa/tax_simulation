# frozen_string_literal: true

require "csv"
require "open-uri"
require "stringio"

module StockValuation
  class SimilarIndustryImporter
    DEFAULT_YEAR = 2025
    DEFAULT_SOURCE_URL = StockValuation::NtaR07PdfCatalog::INDEX_URL
    DEFAULT_CSV_PATH = Rails.root.join("db/seed_data/similar_industries_r07.csv")
    DEFAULT_PDF_URL = StockValuation::NtaR07PdfCatalog::LIST_ALL_URL

    Result = Struct.new(:imported, :skipped, :errors, keyword_init: true)

    # 国税庁公表の業種目は欠番を含め最大115。PDF取込でおおよそ95業種。
    MIN_COMPLETE_COUNT = 90

    # データ未登録・不足時に国税庁PDFから取込（サンプルCSVのみの11件では止めない）
    def self.ensure_data!(year: DEFAULT_YEAR)
      return true if complete_dataset?(year)

      importer = new(year: year)
      if File.exist?(DEFAULT_CSV_PATH) && csv_row_count(DEFAULT_CSV_PATH) >= MIN_COMPLETE_COUNT
        importer.import_csv
        SimilarIndustry.normalize_all_names!(year)
        return true if complete_dataset?(year)
      end

      importer.import_nta_r07_list_all
      importer.import_nta_r07_split_pdfs unless complete_dataset?(year)
      SimilarIndustry.normalize_all_names!(year)
      SimilarIndustry.dedupe_for_year!(year)
      complete_dataset?(year)
    rescue StandardError => e
      Rails.logger.error("[SimilarIndustryImporter] #{e.class}: #{e.message}")
      false
    end

    def self.complete_dataset?(year)
      SimilarIndustry.where(year: year).where("profit_c > 0 AND net_asset_d > 0").count >= MIN_COMPLETE_COUNT
    end

    def self.csv_row_count(path)
      return 0 unless File.exist?(path)

      count = 0
      CSV.foreach(path, headers: true) { count += 1 }
      count
    rescue StandardError
      0
    end

    def initialize(year: DEFAULT_YEAR, source_url: DEFAULT_SOURCE_URL)
      @year = year
      @source_url = source_url
    end

    def import_csv(path = DEFAULT_CSV_PATH)
      raise "CSVファイルが見つかりません: #{path}" unless File.exist?(path)

      rows = []
      CSV.foreach(path, headers: true) { |row| rows << row_to_attributes(row) }
      save_rows(rows, source_url: path.to_s)
    end

    # list_all.pdf または任意の国税庁PDFから取込
    def import_from_pdf(url = DEFAULT_PDF_URL, major_category: nil, middle_category: nil)
      pdf_data = download_pdf(url)
      rows = parse_pdf(pdf_data).map do |row|
        row.merge(
          major_category: major_category || row[:major_category],
          middle_category: middle_category || row[:middle_category],
          source_url: url
        )
      end
      save_rows(rows, source_url: url)
    end

    # 令和7年分: list_01〜15 の分割PDFを順に取込（list_all より安定）
    def import_nta_r07_split_pdfs
      total_imported = 0
      total_skipped = 0
      errors = []

      StockValuation::NtaR07PdfCatalog::SPLIT_PDFS.each_value do |meta|
        result = import_from_pdf(
          meta[:url],
          major_category: meta[:major],
          middle_category: meta[:middle]
        )
        total_imported += result.imported
        total_skipped += result.skipped
        errors.concat(result.errors)
      end

      SimilarIndustry.dedupe_for_year!(@year)
      Result.new(imported: total_imported, skipped: total_skipped, errors: errors)
    end

    # list_all.pdf 一括取込
    def import_nta_r07_list_all
      import_from_pdf(StockValuation::NtaR07PdfCatalog::LIST_ALL_URL)
    end

    # HTMLページからの取得（従来・実験的）
    def import_from_html(url = @source_url)
      html = URI.open(url, read_timeout: 30, "User-Agent" => user_agent).read
      rows = parse_html_table(html)
      raise "HTMLから業種データを抽出できませんでした。PDFまたはCSV取込を利用してください。" if rows.empty?

      save_rows(rows, source_url: url)
    rescue StandardError => e
      Result.new(imported: 0, skipped: 0, errors: [e.message])
    end

    private

    def download_pdf(url)
      URI.open(url, read_timeout: 120, open_timeout: 30, "User-Agent" => user_agent).read
    end

    def parse_pdf(binary)
      io = StringIO.new(binary)
      StockValuation::PdfSimilarIndustryParser.new(io).parse
    end

    def save_rows(rows, source_url:)
      imported = 0
      skipped = 0
      errors = []

      rows.each do |attrs|
        attrs = attrs.merge(industry_number: normalize_industry_number(attrs[:industry_number]))
        next unless valid_import_row?(attrs)

        record = SimilarIndustry.find_or_initialize_by(
          year: @year,
          industry_number: attrs[:industry_number].to_s
        )
        merged = merge_import_attributes(record, attrs)
        record.assign_attributes(
          merged.merge(year: @year, source_url: source_url || @source_url)
        )
        if record.save
          imported += 1
        else
          skipped += 1
          errors << "#{attrs[:industry_number]}: #{record.errors.full_messages.join(', ')}"
        end
      end

      SimilarIndustry.dedupe_for_year!(@year)
      Result.new(imported: imported, skipped: skipped, errors: errors)
    end

    def normalize_industry_number(value)
      stripped = value.to_s.strip
      return stripped if stripped.blank? || !stripped.match?(/\A\d+\z/)

      stripped.to_i.to_s
    end

    def row_to_attributes(row)
      {
        industry_number: row["industry_number"].to_s.strip,
        major_category: row["major_category"]&.strip,
        middle_category: row["middle_category"]&.strip,
        small_category: row["small_category"]&.strip,
        industry_name: row["industry_name"].to_s.strip,
        stock_price_a_average: decimal(row["stock_price_a_average"]),
        dividend_b: decimal(row["dividend_b"]),
        profit_c: decimal(row["profit_c"]),
        net_asset_d: decimal(row["net_asset_d"])
      }
    end

    def decimal(value)
      value.to_s.delete(",").to_d
    end

    def user_agent
      "TaxSimulation/1.0 (+https://www.nta.go.jp; stock valuation importer)"
    end

    def merge_import_attributes(record, attrs)
      merged = attrs.dup
      return merged unless record.persisted?

      %i[dividend_b profit_c net_asset_d stock_price_a_average].each do |key|
        merged[key] = record.public_send(key) if merged[key].to_f.zero? && record.public_send(key).to_f.positive?
      end

      if SimilarIndustry.valid_name_score(merged[:industry_name]) < SimilarIndustry.valid_name_score(record.industry_name)
        merged[:industry_name] = record.industry_name
      end

      merged
    end

    def valid_import_row?(attrs)
      num = attrs[:industry_number].to_s.to_i
      a = attrs[:stock_price_a_average].to_f
      return false if num <= 0 || num > SimilarIndustry::MAX_INDUSTRY_NUMBER
      return false if a <= 0 || a > 50_000
      return false if attrs[:industry_name].to_s.match?(/\A業種\d+\z/) && attrs[:dividend_b].to_f.zero?
      return false if attrs[:industry_name].to_s.match?(/令和|年分|月分|公表|年月/)
      return false if attrs[:profit_c].to_f.zero? || attrs[:net_asset_d].to_f.zero?

      true
    end

    def parse_html_table(html)
      rows = []
      html.scan(/<tr[^>]*>(.*?)<\/tr>/mi) do |tr_match|
        cells = tr_match[0].scan(/<t[dh][^>]*>(.*?)<\/t[dh]>/mi).flatten.map { |c| strip_tags(c).strip }
        next if cells.size < 7

        industry_number = cells[0][/\d+/]
        next unless industry_number

        rows << {
          industry_number: industry_number,
          major_category: cells[1],
          middle_category: cells[2],
          small_category: cells[3],
          industry_name: cells[4],
          stock_price_a_average: decimal(cells[5]),
          dividend_b: decimal(cells[6]),
          profit_c: decimal(cells[7] || "0"),
          net_asset_d: decimal(cells[8] || "0")
        }
      end
      rows
    end

    def strip_tags(text)
      text.gsub(/<[^>]+>/, "").gsub(/&nbsp;/, " ").gsub(/\s+/, " ")
    end
  end
end
