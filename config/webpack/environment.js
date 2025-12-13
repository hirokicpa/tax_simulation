// config/webpack/environment.js
const { environment } = require('@rails/webpacker')
const path = require('path')

// ★ vue-loader v15 は default export（波括弧は使わない）
const VueLoaderPlugin = require('vue-loader/lib/plugin')

// .vue ローダー（余計な options は不要）
environment.loaders.prepend('vue', {
  test: /\.vue$/,
  use: [{ loader: 'vue-loader' }]
})

// プラグイン登録
environment.plugins.prepend('VueLoaderPlugin', new VueLoaderPlugin())

// Babel が node_modules を処理しないように明示（axios 1.7 対策）
const babelLoader = environment.loaders.get('babel')
if (babelLoader) {
  // 自分のアプリコードだけに限定
  babelLoader.include = [path.resolve(__dirname, '../../app/javascript')]
  // 念のため除外も併用
  babelLoader.exclude = /node_modules/
}

// SASS を dart-sass で動かす（任意だが推奨）
const sass = environment.loaders.get('sass')
if (sass) {
  const s = sass.use.find(u => (u.loader || '').includes('sass-loader'))
  if (s) {
    s.options = Object.assign({}, s.options, { implementation: require('sass') })
  }
}

// Vue のランタイム＋コンパイラ版を使う（<template> をそのまま利用）
environment.config.merge({
  resolve: {
    alias: { vue$: 'vue/dist/vue.esm.js' },
    extensions: ['.js', '.jsx', '.vue', '.scss', '.css']
  }
})

module.exports = environment
