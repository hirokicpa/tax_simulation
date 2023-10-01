export default {
  methods: {
    addComma(e) {
      var halfWidthDigit = function(str) {
        return String.fromCharCode(str.charCodeAt(0) - 0xFEE0);
      }
      var regex = /^([0-9,|０-９]+$)?$/;
      if (regex.test(e.target.value)) {
        return Number(e.target.value.replace(/,/g, '').replace(/[０-９]/g, halfWidthDigit)).toLocaleString();
      } else {
        alert("半角数字で入力してください。");
      }
    },
    removeComma(e) {
      return e.target.value.replace(/,/g, '');
    },
    convertHalfWidthDigit(e) {
      var halfWidthDigit = function(str) {
        return String.fromCharCode(str.charCodeAt(0) - 0xFEE0);
      }
      var regex = /^([0-9,|０-９]+(\.\d+)?$)?$/;
      if (regex.test(e.target.value)) {
        return Number(e.target.value.replace(/[０-９]/g, halfWidthDigit));
      } else {
        alert("半角数字で入力してください。");
      }
    }
  }
}