/* eslint no-console:0 */
// This file is automatically compiled by Webpack, along with any other files
// present in this directory. You're encouraged to place your actual application logic in
// a relevant structure within app/javascript and only use these pack files to reference
// that code so it'll be compiled.
//
// To reference this file, add <%= javascript_pack_tag 'application' %> to the appropriate
// layout file, like app/views/layouts/application.html.erb

import '../stylesheets/application';

// jQuery
import $ from 'jquery';
// PopperJS
import Popper from 'popper.js';
// Bootstrap 4
import 'bootstrap';
import 'bootstrap/dist/css/bootstrap.min.css';
import 'mdbootstrap/css/mdb.min.css';
// font-awesome
import '@fortawesome/fontawesome-free/js/all';

import Rails from '@rails/ujs';
Rails.start();