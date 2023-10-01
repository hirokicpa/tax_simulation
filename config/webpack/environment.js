const { environment } = require('@rails/webpacker')
const vue =  require('./loaders/vue')
const webpack = require('webpack')

environment.loaders.append('vue', vue)

// 以下のエラーが出たからalias追加した (参考: https://stackoverflow.com/questions/50473630/rails-webpacker-vue-you-are-using-the-runtime-only-build-of-vue-where-the)
// [Vue warn]: You are using the runtime-only build of Vue where the template compiler is not available. Either pre-compile the templates into render functions, or use the compiler-included build.
environment.config.resolve.alias = { 'vue$': 'vue/dist/vue.esm.js' };
module.exports = environment

environment.plugins.prepend(
  'Provide',
  new webpack.ProvidePlugin({
    $: 'jquery',
    jQuery: 'jquery',
    jquery: 'jquery'
  })
)
