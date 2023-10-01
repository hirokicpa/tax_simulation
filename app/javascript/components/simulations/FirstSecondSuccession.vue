<template>
  <div class="row">
    <div class="card mx-auto col-12 col-md-10 col-lg-9">
      <div class="card-body px-0">
        <h5 class="card-title text-center mb-3">
          <i class="fa fa-calculator" aria-hidden="true"></i> 1次相続による2次相続への影響の<br>シミュレーション
        </h5>
        <div class="row form-caution">
          <div class="col-12 mb-1 px-1">
            <div class="caution-mark-block">※</div>
            <div class="caution-text-block">
              値はすべて<strong>半角数字</strong>で入力してください。
            </div>
          </div>
          <div class="col-12 mb-1 px-1">
            <div class="caution-mark-block">※</div>
            <div class="caution-text-block">
              遺産総額の金額は、各種特例や非課税枠及び債務控除等を控除済みの課税価格の金額としています。
            </div>
          </div>
        </div>
        <form @submit.prevent accept-charset="UTF-8">
          <table class="table">
            <tbody>
              <tr>
                <td class="align-middle no-break pr-0">現在の遺産総額</td>
                <td>
                  <div class="row">
                    <div class="col-9 col-lg-6">
                      <input :value="totalHeritage" @blur="totalHeritage = addComma($event)" @focus="totalHeritage = removeComma($event)"
                             type="tel" class="form-control text-right input-num">
                    </div>
                    <div class="py-2">万円</div>
                  </div>
                </td>
              </tr>
              <tr>
                <td class="align-middle">子供の人数</td>
                <td>
                  <div>
                    <div class="custom-control custom-radio mb-2">
                      <input v-model="checkHeirChildren" type="radio"
                             value="0" class="custom-control-input" id="heir_children_0">
                      <label class="custom-control-label" for="heir_children_0">子供</label>
                    </div>
                    <select v-model="childrenCount" class="form-control col-12 col-lg-8">
                      <option value="0" disabled selected>選択してください</option>
                      <option value="1">1人</option>
                      <option value="2">2人</option>
                      <option value="3">3人</option>
                      <option value="4">4人</option>
                      <option value="5">5人</option>
                    </select>
                  </div>
                </td>
              </tr>
              <tr class="border-bottom">
                <td class="align-middle no-break pr-0">相続時における<br>配偶者の固有の財産額</td>
                <td class="align-middle">
                  <div class="row">
                    <div class="col-9 col-lg-6">
                      <input :value="mateOwnHeritage" @blur="mateOwnHeritage = addComma($event)" @focus="mateOwnHeritage = removeComma($event)"
                             type="tel" class="form-control text-right input-num">
                    </div>
                    <div class="py-2">万円</div>
                  </div>
                </td>
              </tr>
            </tbody>
          </table>
          <div class="text-center">
            <input @click="clickCalcBtn($event)" type="submit" value="計算する" class="btn btn-navy">
          </div>
        </form>
      </div>
    </div>

    <div class="mx-auto my-3 col-12 col-md-10 col-lg-9 px-0" ref="scrollPoint">
      <div v-show="firstResultsI !== ''" class="card">
        <div class="card-body">
          <table class="table">
            <thead>
              <tr>
                <th scope="col" class="text-center align-middle pr-0">1次相続時の<br>配偶者の<div class="no-break">遺産取得割合</div></th>
                <th scope="col" class="text-center align-middle pr-0">1次<div class="no-break">相続税</div></th>
                <th scope="col" class="text-center align-middle pr-0">2次<div class="no-break">相続税</div></th>
                <th scope="col" class="text-center align-middle pr-0">1次＋2次<div class="no-break">相続税の合計</div></th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="i in 11">
                <th scope="row" class="text-center pr-0">{{ maritalPercent[i - 1] }}</th>
                <td class="text-center">{{ (firstResultsS[i - 1]) }}</td>
                <td class="text-center pr-0">{{ (secondResultsS[i - 1]) }}</td>
                <th class="text-center pr-0">{{ (totalResults[i - 1]) }}</th>
              </tr>
            </tbody>
          </table>
          <commit-chart :chartData="chartData" :options="chartOptions"></commit-chart>
          <div class="card-title text-center my-3">
            <h6><strong>1次相続時の配偶者の遺産取得割合: {{ minMaritalPercent }}</strong></h6>
            <h6><strong>1次＋2次相続税の合計: {{ minTotalResult.toLocaleString() }} 万円</strong></h6>
            <h6><strong>上記の場合が最小値となります。</strong></h6>
          </div>
        </div>
      </div>
    </div>
    <cautionary-statement :is-succession-gift="false"></cautionary-statement>
  </div>
</template>