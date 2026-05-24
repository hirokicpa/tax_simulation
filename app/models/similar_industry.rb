class SimilarIndustry < ApplicationRecord
  CURRENT_YEAR = 2025
  MAX_INDUSTRY_NUMBER = 115

  before_validation :normalize_industry_number

  validates :year, presence: true
  validates :industry_number, presence: true, uniqueness: { scope: :year }
  validates :industry_name, presence: true
  validates :stock_price_a_average, presence: true, numericality: true

  scope :for_year, lambda { |year = CURRENT_YEAR|
    where(year: year)
      .where("CAST(industry_number AS INTEGER) BETWEEN 1 AND ?", MAX_INDUSTRY_NUMBER)
      .order(Arel.sql("CAST(industry_number AS INTEGER)"), :industry_name)
  }

  # 業種目 No.1〜No.115 の順で返す（欠番は除く）
  def self.ordered_for_select(year = CURRENT_YEAR)
    by_number = for_year(year).index_by(&:display_number)
    (1..MAX_INDUSTRY_NUMBER).filter_map { |n| by_number[n] }
  end

  # 先頭ゼロ付きなど同一番号の重複レコードを統合（例: "01" と "1"）
  def self.dedupe_for_year!(year = CURRENT_YEAR)
    purge_invalid_numbers!(year)

    where(year: year).to_a.group_by { |r| r.industry_number.to_i }.each_value do |records|
      next if records.size <= 1

      keeper = records.max_by { |r| [data_completeness_score(r), valid_name_score(r.industry_name), r.updated_at] }
      records.reject { |r| r.id == keeper.id }.each(&:destroy)
      normalized = keeper.industry_number.to_i.to_s
      keeper.update_columns(industry_number: normalized) if keeper.industry_number != normalized
    end
  end

  def self.valid_name_score(name)
    return -1 if name.blank? || name.match?(/令和|年分|月分|公表|年月/)
    return -1 if name.match?(/に該当|のうち、|,,/)

    name.length
  end

  def self.data_completeness_score(record)
    score = 0
    score += 100 if record.profit_c.to_f.positive? && record.net_asset_d.to_f.positive?
    score += 20 if record.dividend_b.to_f.positive?
    score += 10 if record.stock_price_a_average.to_f.positive?
    score
  end

  def self.needs_dedupe?(year = CURRENT_YEAR)
    numbers = where(year: year).pluck(:industry_number)
    return false if numbers.empty?

    numbers.any? { |n| n.match?(/\A0+\d+\z/) } || numbers.map(&:to_i).uniq.size != numbers.size
  end

  # 国税庁一覧表の「令和6年平均」列（前年平均株価）
  def prior_year_average_stock_price
    stock_price_a_average.to_f
  end

  def display_label
    parts = ["No.#{display_number}", industry_name]
    parts << major_category if major_category.present?
    parts.join(" ")
  end

  def display_number
    industry_number.to_i
  end

  def self.purge_invalid_numbers!(year = CURRENT_YEAR)
    where(year: year).where("CAST(industry_number AS INTEGER) > ? OR CAST(industry_number AS INTEGER) < 1", MAX_INDUSTRY_NUMBER).delete_all
  end

  private

  def normalize_industry_number
    return if industry_number.blank?

    stripped = industry_number.to_s.strip
    self.industry_number = stripped.to_i.to_s if stripped.match?(/\A\d+\z/)
  end
end
