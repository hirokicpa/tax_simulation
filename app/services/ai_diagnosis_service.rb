# frozen_string_literal: true

require "net/http"
require "json"
require "openssl"

# 計算結果をもとに Google AI（Gemini）で社長向け診断コメントを生成（税額計算は行わない）
class AiDiagnosisService
  SECTIONS = [
    "総合診断",
    "主なリスク",
    "優先して検討すべき対策",
    "放置した場合の問題",
    "個別相談で確認すべき事項",
    "最後の一言"
  ].freeze

  Result = Struct.new(
    :available,
    :sections,
    :raw_text,
    :error_message,
    keyword_init: true
  )

  def initialize(diagnosis_result, input_summary: {})
    @diagnosis = diagnosis_result
    @input_summary = input_summary
  end

  def call
    return fallback_result("Google AI APIキーが未設定です。ルールベースの診断結果を表示しています。") if api_key.blank?

    response = request_google_ai
    text = extract_text(response)
    return fallback_result(parse_error(response)) if text.blank?

    Result.new(
      available: true,
      sections: parse_sections(text),
      raw_text: text,
      error_message: nil
    )
  rescue StandardError => e
    Rails.logger.error("[AiDiagnosisService] #{e.class}: #{e.message}")
    fallback_result("AI診断の生成に失敗しました。ルールベースの診断結果を表示しています。（#{e.message}）")
  end

  private

  def api_key
    ENV["GOOGLE_AI_API_KEY"].presence || ENV["GEMINI_API_KEY"].to_s.strip.presence
  end

  def model
    ENV.fetch("GOOGLE_AI_MODEL", "gemini-2.5-flash")
  end

  def request_google_ai
    uri = URI("https://generativelanguage.googleapis.com/v1beta/models/#{model}:generateContent")
    body = {
      systemInstruction: {
        parts: [{ text: system_prompt }]
      },
      contents: [
        {
          role: "user",
          parts: [{ text: user_prompt }]
        }
      ],
      generationConfig: {
        temperature: 0.4
      }
    }

    http = Net::HTTP.new(uri.host, uri.port)
    configure_https!(http)

    request = Net::HTTP::Post.new(uri)
    request["x-goog-api-key"] = api_key
    request["Content-Type"] = "application/json"
    request.body = body.to_json
    response = http.request(request)
    JSON.parse(response.body)
  end

  def extract_text(response)
    return nil if response["error"]

    response.dig("candidates", 0, "content", "parts", 0, "text").to_s.strip.presence
  end

  def parse_error(response)
    response.dig("error", "message") ||
      response.dig("promptFeedback", "blockReason") ||
      "AIからの応答を取得できませんでした。"
  end

  def configure_https!(http)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    http.open_timeout = 15
    http.read_timeout = 60
    http.cert_store = ssl_cert_store
  end

  def ssl_cert_store
    @ssl_cert_store ||= begin
      store = OpenSSL::X509::Store.new
      store.set_default_paths

      ssl_certificate_paths.each do |path|
        store.add_file(path)
      rescue OpenSSL::X509::StoreError
        # 既に読み込まれている証明書などは無視
      end

      # macOS + OpenSSL 3.x で CRL 取得失敗による verify error を回避
      store.flags = 0 if store.respond_to?(:flags=)

      store
    end
  end

  def ssl_certificate_paths
    [
      ENV["SSL_CERT_FILE"],
      (OpenSSL::X509::DEFAULT_CERT_FILE if defined?(OpenSSL::X509::DEFAULT_CERT_FILE)),
      "/etc/ssl/cert.pem",
      "/private/etc/ssl/cert.pem",
      "/usr/local/etc/openssl@3/cert.pem",
      "/usr/local/etc/openssl/cert.pem",
      "/opt/homebrew/etc/openssl@3/cert.pem",
      "/opt/homebrew/etc/ca-certificates/cert.pem"
    ].compact.select { |path| File.file?(path) }.uniq
  end

  def system_prompt
    <<~PROMPT
      あなたは日本の事業承継・相続税・自社株対策に詳しい税理士です。

      ただし、あなたは税額計算そのものを行ってはいけません。
      税額・株価・リスクスコアは、システムから渡された計算結果のみを使用してください。

      目的は、中小企業オーナーに対して、
      事業承継上のリスク、納税資金リスク、自社株リスク、後継者リスクを
      わかりやすく説明し、専門家への個別相談につなげることです。

      断定的な節税効果は述べず、
      「可能性」「検討余地」「専門家による詳細確認が必要」という表現を使ってください。

      出力は以下の見出し形式（Markdown）にしてください。

      ## 1. 総合診断
      ## 2. 主なリスク
      ## 3. 優先して検討すべき対策
      ## 4. 放置した場合の問題
      ## 5. 個別相談で確認すべき事項
      ## 6. 最後の一言

      各セクションは2〜4文程度。専門知識のない中小企業オーナーにも伝わるように。
      恐怖を煽りすぎず、ただし早期対策の必要性が伝わる文章にしてください。
    PROMPT
  end

  def user_prompt
    d = @diagnosis
    <<~PROMPT
      以下の会社について、事業承継リスク診断をしてください。

      【入力情報】
      代表者年齢：#{d.president_age}歳
      後継者：#{d.successor_label}
      配偶者：#{d.has_spouse ? '有' : '無'}
      子供の人数：#{d.count_heir_children}人
      #{d.has_spouse ? "配偶者の遺産取得割合（選択）：#{d.spouse_acquisition_rate}%" : ''}
      売上：#{format_yen(d.sales)}円
      営業利益：#{format_yen(d.operating_profit)}円
      純資産：#{format_yen(d.net_assets)}円
      借入金：#{format_yen(d.debt)}円
      遺産総額：#{format_yen(d.total_estate)}円（自社株＋不動産＋それ以外の財産＋現預金）
      不動産：#{format_yen(d.real_estate_value)}円
      それ以外の財産：#{format_yen(d.other_assets)}円
      現預金：#{format_yen(d.cash_assets)}円
      自社株評価額：#{format_yen(d.company_value)}円#{d.company_value_estimated ? '（簡易推定）' : ''}
      相続税概算：#{format_yen(d.estimated_inheritance_tax)}円#{d.has_spouse ? "（配偶者取得#{d.spouse_acquisition_rate}%・税額軽減反映後）" : ''}
      課税遺産総額：#{format_yen(d.taxable_estate)}円
      納税資金不足額：#{format_yen([d.tax_payment_shortage, 0].max)}円

      【システム計算結果】
      事業承継危険度：#{d.succession_risk_score}点（#{d.succession_risk_level}）
      自社株リスク：#{d.stock_risk_score}点（#{d.stock_risk_level}）
      納税資金不足リスク：#{d.tax_funding_risk_score}点（#{d.tax_funding_risk_level}）
      M&A検討必要度：#{d.ma_necessity_score}点（#{d.ma_necessity_level}）
      総合リスク：#{d.overall_risk_score}点（#{d.overall_risk_level}）
    PROMPT
  end

  def format_yen(amount)
    amount.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end

  def parse_sections(text)
    sections = {}
    current_key = nil
    buffer = []

    text.each_line do |line|
      if (match = line.match(/\A#+\s*(?:\d+\.\s*)?(.+?)\s*\z/))
        sections[current_key] = buffer.join.strip if current_key
        current_key = match[1].strip
        buffer = []
      else
        buffer << line
      end
    end
    sections[current_key] = buffer.join.strip if current_key

    SECTIONS.index_with do |title|
      sections[title] || sections.find { |k, _| k&.include?(title) }&.last
    end.compact
  end

  def fallback_result(message)
    d = @diagnosis
    Result.new(
      available: false,
      sections: fallback_sections,
      raw_text: nil,
      error_message: message
    )
  end

  def fallback_sections
    d = @diagnosis
    {
      "総合診断" => "総合リスクは#{d.overall_risk_level}（#{d.overall_risk_score}点）です。#{d.successor_label}の状況、自社株評価額、納税資金のバランスから、専門家による詳細確認の検討余地があります。",
      "主なリスク" => [
        ("後継者が未定または不在のため、承継計画の早期策定が必要です。" if d.succession_risk_score >= 40),
        ("自社株評価額が高く、相続税負担増の可能性があります。" if d.stock_risk_score >= 40),
        ("納税資金が不足する可能性があります（不足額概算：#{format_yen([d.tax_payment_shortage, 0].max)}円）。" if d.tax_payment_shortage.positive?)
      ].compact.join("\n"),
      "優先して検討すべき対策" => d.immediate_actions.map { |a| "・#{a}" }.join("\n"),
      "放置した場合の問題" => "承継準備が遅れると、後継者育成・株価対策・納税資金確保の選択肢が狭まる可能性があります。",
      "個別相談で確認すべき事項" => "自社株評価の詳細、事業承継税制の適用可能性、納税資金確保方法、後継者への株式移転スキームについて、税理士・弁護士等にご確認ください。",
      "最後の一言" => "本診断は概算です。実際の相続税・承継計画は個別事情により大きく異なります。お早めに専門家へご相談ください。"
    }
  end
end
