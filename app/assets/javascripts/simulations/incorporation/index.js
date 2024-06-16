var breakdown1 = $('#breakdown1').val() || 0;
var breakdown2 = $('#breakdown2').val()|| 0;
var breakdown3 = $('#breakdown3').val()|| 0;
var breakdown4 = $('#breakdown4').val()|| 0;
var breakdown5 = $('#breakdown5').val()|| 0;
var breakdown6 = $('#breakdown6').val()|| 0;
var breakdown7 = $('#breakdown7').val()|| 0;
var breakdown8 = $('#breakdown8').val()|| 0;
var breakdown9 = $('#breakdown9').val()|| 0;
var breakdown10 = $('#breakdown10').val()|| 0;
var breakdown11 = $('#breakdown11').val()|| 0;
var breakdown12 = $('#breakdown12').val()|| 0;

$('#breakdown1').keyup(function(){
  breakdown1 = $(this).val();
  total_breakdown();
});

$('#breakdown2').keyup(function(){
  breakdown2 = $(this).val();
  total_breakdown();
});
$('#breakdown3').keyup(function(){
  breakdown3 = $(this).val();
  total_breakdown();
});
$('#breakdown4').keyup(function(){
  breakdown4 = $(this).val();
  total_breakdown();
});
$('#breakdown5').keyup(function(){
  breakdown5 = $(this).val();
  total_breakdown();
});
$('#breakdown6').keyup(function(){
  breakdown6 = $(this).val();
  total_breakdown();
});
$('#breakdown7').keyup(function(){
  breakdown7 = $(this).val();
  total_breakdown();
});
$('#breakdown8').keyup(function(){
  breakdown8 = $(this).val();
  total_breakdown();
});
$('#breakdown9').keyup(function(){
  breakdown9 = $(this).val();
  total_breakdown();
});
$('#breakdown10').keyup(function(){
  breakdown10 = $(this).val();
  total_breakdown();
});
$('#breakdown11').keyup(function(){
  breakdown11 = $(this).val();
  total_breakdown();
});
$('#breakdown12').keyup(function(){
  breakdown12 = $(this).val();
  total_breakdown();
});

function total_breakdown(){
  var total_income_deduction = Number($('#basic_deduction').val()) + Number($('#breakdown1').val()) + Number($('#breakdown2').val()) + Number($('#breakdown3').val()) + Number($('#breakdown4').val()) + Number($('#breakdown5').val()) + Number($('#breakdown6').val()) + Number($('#breakdown7').val()) + Number($('#breakdown8').val()) + Number($('#breakdown9').val()) + Number($('#breakdown10').val()) + Number($('#breakdown11').val()) + Number($('#breakdown12').val())
  if (total_income_deduction !== 48){
    $('#total_income_deduction').val(total_income_deduction);
    $('#total_income_deduction').prop('disabled', true);
  } else {
    $('#total_income_deduction').val("48");
    $('#total_income_deduction').prop('disabled', false);
  }
  result_taxable_income();
}

$('#reset_btn').click(function(){
  breakdown1 = 0
  breakdown2 = 0
  breakdown3 = 0
  breakdown4 = 0
  breakdown5 = 0
  breakdown6 = 0
  breakdown7 = 0
  breakdown8 = 0
  breakdown9 = 0
  breakdown10 = 0
  breakdown11 = 0
  breakdown12 = 0

  $('.breakdown').keyup(function() {
  total_breakdown();
});


  total_income_deduction = 0
  $(".breakdown").val("");
  $('#total_income_deduction').val("48");
  $('#total_income_deduction').prop('disabled', false);
  result_taxable_income();
});