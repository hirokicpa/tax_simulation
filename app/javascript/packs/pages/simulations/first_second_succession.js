import Vue from 'vue';
import FirstSecondSuccession from '../../../components/simulations/FirstSecondSuccession.vue';

document.addEventListener('DOMContentLoaded', () => {
  const app = new Vue({
    el: '#app',
    render: h => h(FirstSecondSuccession)
  });
});