# frozen_string_literal: true

module Simulations
  class BusinessSuccessionDiagnosisController < ApplicationController
    helper BusinessSuccessionDiagnosisHelper

    def index
      @consultation_url = consultation_url
    end

    def result
      validator = Simulations::DiagnosisFormValidator.new(diagnosis_params)
      unless validator.valid?
        flash.now[:alert] = validator.errors
        @consultation_url = consultation_url
        return render :index, status: :unprocessable_entity
      end

      @input = validator.parsed
      @diagnosis = BusinessSuccessionDiagnosisService.new(@input).call
      @ai_diagnosis = AiDiagnosisService.new(@diagnosis).call
      @consultation_url = consultation_url
      @risk_chart_data = @diagnosis.risk_breakdown
    end

    private

    def diagnosis_params
      permitted = params.permit(
        :president_age,
        :successor_status,
        :sales,
        :operating_profit,
        :net_assets,
        :company_value,
        :debt,
        :real_estate_value,
        :other_assets,
        :has_spouse,
        :count_heir_children,
        :spouse_acquisition_rate,
        :cash_assets
      )
      permitted.delete(:spouse_acquisition_rate) unless permitted[:has_spouse].to_s == "1"
      permitted
    end

    def consultation_url
      ENV.fetch("CONSULTATION_URL", "https://forms.gle/placeholder")
    end
  end
end
