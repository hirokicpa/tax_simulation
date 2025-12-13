const simulationMixin = {
  methods: {
    addComma(e) {
      const raw = (e && e.target) ? e.target.value : e
      if (raw === '' || raw === null || raw === undefined) return ''
      const num = String(raw).replace(/,/g, '')
      if (num === '' || isNaN(num)) return ''
      return Number(num).toLocaleString()
    },
    removeComma(e) {
      const raw = (e && e.target) ? e.target.value : e
      if (raw === '' || raw === null || raw === undefined) return ''
      return String(raw).replace(/,/g, '')
    },
    isValidNumber(val) {
      if (val === null || val === undefined) return false
      const num = Number(String(val).replace(/,/g, ''))
      return Number.isFinite(num)
    }
  }
}

export { simulationMixin }
export default simulationMixin
  