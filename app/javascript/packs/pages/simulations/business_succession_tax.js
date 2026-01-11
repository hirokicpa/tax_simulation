import Vue from 'vue'
import BusinessSuccessionTax from '../../../components/BusinessSuccessionTax.vue'

document.addEventListener('DOMContentLoaded', () => {
  const el = document.getElementById('app')
  if (!el) return

  new Vue({
    render: h => h(BusinessSuccessionTax)
  }).$mount(el)
})