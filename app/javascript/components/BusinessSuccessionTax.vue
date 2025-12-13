<template>
  <div class="business-succession-tax">
    <div class="container">
      <h2 class="text-center mb-4">事業承継税制シミュレーション</h2>
      
      <!-- 入力フォーム -->
      <div class="card mb-4">
        <div class="card-header">
          <h5 class="mb-0">基本情報入力</h5>
        </div>
        <div class="card-body">
          <div class="row">
            <div class="col-md-6">
              <div class="mb-3">
                <label class="form-label">遺産総額（万円）</label>
                <input 
                  type="text" 
                  class="form-control" 
                  v-model="formData.total_heritage"
                  @input="formatInput('total_heritage')"
                  placeholder="例：10,000"
                >
              </div>
              <div class="mb-3">
                <label class="form-label">後継者の非上場株式価値（万円）</label>
                <input 
                  type="text" 
                  class="form-control" 
                  v-model="formData.heir_special_stock_value"
                  @input="formatInput('heir_special_stock_value')"
                  placeholder="例：9,000"
                >
              </div>
              <div class="mb-3">
                <label class="form-label">その他の相続人の取得額（万円）</label>
                <input 
                  type="text" 
                  class="form-control" 
                  v-model="formData.other_heir_get_heritage"
                  @input="formatInput('other_heir_get_heritage')"
                  placeholder="例：1,000"
                >
              </div>
            </div>
            <div class="col-md-6">
              <div class="mb-3">
                <label class="form-label">配偶者の有無</label>
                <select class="form-select" v-model="formData.marital_status">
                  <option value="1">配偶者有り</option>
                  <option value="0">配偶者無し</option>
                </select>
              </div>
              <div class="mb-3">
                <label class="form-label">法定相続人の数</label>
                <input 
                  type="number" 
                  class="form-control" 
                  v-model="formData.legal_heir"
                  min="0"
                >
              </div>
              <div class="mb-3">
                <label class="form-label">子の数</label>
                <input 
                  type="number" 
                  class="form-control" 
                  v-model="formData.children_count"
                  min="0"
                >
              </div>
              <div class="mb-3">
                <label class="form-label">兄弟姉妹の数</label>
                <input 
                  type="number" 
                  class="form-control" 
                  v-model="formData.siblings_count"
                  min="0"
                >
              </div>
            </div>
          </div>
          
          <div class="text-center">
            <button 
              class="btn btn-primary btn-lg me-3" 
              @click="calculateHeirRate"
              :disabled="!isFormValid"
            >
              後継者割合を計算
            </button>
            <button 
              class="btn btn-success btn-lg" 
              @click="calculateBusinessSuccession"
              :disabled="!isFormValid"
            >
              事業承継税制を計算
            </button>
          </div>
        </div>
      </div>

      <!-- 後継者割合の結果 -->
      <div v-if="heirRateResult" class="card mb-4">
        <div class="card-header bg-info text-white">
          <h5 class="mb-0">後継者割合の計算結果</h5>
        </div>
        <div class="card-body">
          <div class="row">
            <div class="col-md-6">
              <p><strong>後継者の取得割合：</strong> {{ heirRateResult.heir_rate }}%</p>
              <p><strong>遺産総額：</strong> {{ addComma(heirRateResult.total_heritage) }}万円</p>
            </div>
            <div class="col-md-6">
              <p><strong>後継者の株式価値：</strong> {{ addComma(heirRateResult.heir_special_stock_value) }}万円</p>
              <p><strong>その他の相続人取得額：</strong> {{ addComma(heirRateResult.other_heir_get_heritage) }}万円</p>
            </div>
          </div>
        </div>
      </div>

      <!-- 事業承継税制の結果 -->
      <div v-if="businessSuccessionResult" class="card mb-4">
        <div class="card-header bg-success text-white">
          <h5 class="mb-0">事業承継税制の計算結果</h5>
        </div>
        <div class="card-body">
          <div class="row">
            <div class="col-md-6">
              <h6>基本情報</h6>
              <p><strong>遺産総額：</strong> {{ addComma(businessSuccessionResult.total_heritage) }}万円</p>
              <p><strong>後継者の取得割合：</strong> {{ businessSuccessionResult.heir_rate }}%</p>
              <p><strong>配偶者控除：</strong> {{ addComma(businessSuccessionResult.spouse_deduction) }}万円</p>
              <p><strong>基礎控除：</strong> {{ addComma(businessSuccessionResult.basic_deduction) }}万円</p>
            </div>
            <div class="col-md-6">
              <h6>税額計算</h6>
              <p><strong>課税遺産額：</strong> {{ addComma(businessSuccessionResult.taxable_heritage) }}万円</p>
              <p><strong>通常の相続税額：</strong> {{ addComma(businessSuccessionResult.inheritance_tax) }}万円</p>
              <p><strong>事業承継税制適用：</strong> 
                <span :class="businessSuccessionResult.is_eligible ? 'text-success' : 'text-danger'">
                  {{ businessSuccessionResult.is_eligible ? '適用可能' : '適用不可' }}
                </span>
              </p>
              <p><strong>事業承継税制による軽減額：</strong> {{ addComma(businessSuccessionResult.business_succession_reduction) }}万円</p>
            </div>
          </div>
          
          <div class="alert alert-primary text-center">
            <h4 class="mb-0">
              最終税額：<strong>{{ addComma(businessSuccessionResult.final_tax) }}万円</strong>
            </h4>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import { simulationMixin } from '../packs/pages/simulations/simulation_global.js'
import axios from 'axios'

export default {
  name: 'BusinessSuccessionTax',
  mixins: [simulationMixin],
  data() {
    return {
      formData: {
        total_heritage: '',
        heir_special_stock_value: '',
        other_heir_get_heritage: '',
        marital_status: '1',
        legal_heir: 0,
        children_count: 0,
        siblings_count: 0,
        marital_rate: 7.0
      },
      heirRateResult: null,
      businessSuccessionResult: null
    }
  },
  computed: {
    isFormValid() {
      return this.isValidNumber(this.formData.total_heritage) &&
             this.isValidNumber(this.formData.heir_special_stock_value) &&
             this.isValidNumber(this.formData.other_heir_get_heritage) &&
             this.formData.total_heritage > 0
    }
  },
  methods: {
    formatInput(field) {
      const value = this.removeComma(this.formData[field])
      if (this.isValidNumber(value)) {
        this.formData[field] = this.addComma(value)
      }
    },
    
    async calculateHeirRate() {
      try {
        const response = await axios.get('/simulations/business_succession_tax/result_heir_rate', {
          params: {
            total_heritage: this.removeComma(this.formData.total_heritage),
            heir_special_stock_value: this.removeComma(this.formData.heir_special_stock_value),
            other_heir_get_heritage: this.removeComma(this.formData.other_heir_get_heritage)
          }
        })
        this.heirRateResult = response.data
      } catch (error) {
        console.error('後継者割合の計算エラー:', error)
        alert('計算中にエラーが発生しました')
      }
    },
    
    async calculateBusinessSuccession() {
      try {
        const response = await axios.get('/simulations/business_succession_tax/result_business_succession', {
          params: {
            total_heritage: this.removeComma(this.formData.total_heritage),
            heir_special_stock_value: this.removeComma(this.formData.heir_special_stock_value),
            other_heir_get_heritage: this.removeComma(this.formData.other_heir_get_heritage),
            marital_status: this.formData.marital_status,
            legal_heir: this.formData.legal_heir,
            children_count: this.formData.children_count,
            siblings_count: this.formData.siblings_count,
            marital_rate: this.formData.marital_rate
          }
        })
        this.businessSuccessionResult = response.data
      } catch (error) {
        console.error('事業承継税制の計算エラー:', error)
        alert('計算中にエラーが発生しました')
      }
    }
  }
}
</script>

<style scoped>
.business-succession-tax {
  padding: 20px 0;
}

.card {
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}

.form-label {
  font-weight: 600;
}

.alert {
  border-radius: 8px;
}

.btn {
  border-radius: 6px;
  padding: 12px 24px;
}
</style>

