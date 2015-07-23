//<!-- Modified by Mike (Bambr) V. Andreev for FMS web interface -->
//<!-- modified 2003.06.09 -->

//<!-- Modified by Mike (Bambr) V. Andreev for web site http://www.kccm.ru -->
//<!-- modified 2000.12.19 -->

//<!-- Original:  Kedar R. Bhave (softricks@hotmail.com) -->
//<!-- Web Site:  http://www.softricks.com -->
//<!-- This script and many more are available free online at -->
//<!-- The JavaScript Source!! http://javascript.internet.com -->

var ResFormFieldType = 'input';
var CSSFILE = "/caa/css/calendar.css";

var weekend = [5,6];

var gNow = new Date();
var ggWinCal;
var CurrentCalendar;

Calendar.Months = ["Январь", "Февраль", "Март", "Апрель", "Май", "Июнь","Июль", "Август", "Сентябрь", "Октябрь", "Ноябрь", "Декабрь"];

// Non-Leap year Month days..
Calendar.DOMonth = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
// Leap year Month days..
Calendar.lDOMonth = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

function Calendar( suffix, p_WinCal, month, year ) 
{
	if ((month == null) || (year == null))	return;

	if (p_WinCal == null)
		this.gWinCal = ggWinCal;
	else
		this.gWinCal = p_WinCal;
	
	this.gMonthName = Calendar.get_month(month);
	this.gMonth = new Number(month);
	this.gYearly = false;

	this.gYear = year;
	this.gReturnForm = ReturnForm;
	this.gReturnSuffix = suffix;
}

Calendar.get_month = Calendar_get_month;
Calendar.get_daysofmonth = Calendar_get_daysofmonth;
Calendar.calc_month_year = Calendar_calc_month_year;
Calendar.print = Calendar_print;

function Calendar_get_month(monthNo) {
	return Calendar.Months[monthNo];
}

function Calendar_get_daysofmonth(monthNo, p_year) {
	/* 
	Check for leap year ..
	1.Years evenly divisible by four are normally leap years, except for... 
	2.Years also evenly divisible by 100 are not leap years, except for... 
	3.Years also evenly divisible by 400 are leap years. 
	*/
	if ((p_year % 4) == 0) {
		if ((p_year % 100) == 0 && (p_year % 400) != 0)
			return Calendar.DOMonth[monthNo];
	
		return Calendar.lDOMonth[monthNo];
	} else
		return Calendar.DOMonth[monthNo];
}

function Calendar_calc_month_year(p_Month, p_Year, incr) {
	/* 
	Will return an 1-D array with 1st element being the calculated month 
	and second being the calculated year 
	after applying the month increment/decrement as specified by 'incr' parameter.
	'incr' will normally have 1/-1 to navigate thru the months.
	*/
	var ret_arr = new Array();
	
	if (incr == -1) {
		// B A C K W A R D
		if (p_Month == 0) {
			ret_arr[0] = 11;
			ret_arr[1] = parseInt(p_Year) - 1;
		}
		else {
			ret_arr[0] = parseInt(p_Month) - 1;
			ret_arr[1] = parseInt(p_Year);
		}
	} else if (incr == 1) {
		// F O R W A R D
		if (p_Month == 11) {
			ret_arr[0] = 0;
			ret_arr[1] = parseInt(p_Year) + 1;
		}
		else {
			ret_arr[0] = parseInt(p_Month) + 1;
			ret_arr[1] = parseInt(p_Year);
		}
	}
	
	return ret_arr;
}

function Calendar_print() {
	ggWinCal.print();
}

function Calendar_calc_month_year(p_Month, p_Year, incr) {
	/* 
	Will return an 1-D array with 1st element being the calculated month 
	and second being the calculated year 
	after applying the month increment/decrement as specified by 'incr' parameter.
	'incr' will normally have 1/-1 to navigate thru the months.
	*/
	var ret_arr = new Array();
	
	if (incr == -1) {
		// B A C K W A R D
		if (p_Month == 0) {
			ret_arr[0] = 11;
			ret_arr[1] = parseInt(p_Year) - 1;
		}
		else {
			ret_arr[0] = parseInt(p_Month) - 1;
			ret_arr[1] = parseInt(p_Year);
		}
	} else if (incr == 1) {
		// F O R W A R D
		if (p_Month == 11) {
			ret_arr[0] = 0;
			ret_arr[1] = parseInt(p_Year) + 1;
		}
		else {
			ret_arr[0] = parseInt(p_Month) + 1;
			ret_arr[1] = parseInt(p_Year);
		}
	}
	
	return ret_arr;
}

// This is for compatibility with Navigator 3, we have to create and discard one object before the prototype object exists.
new Calendar();

Calendar.prototype.getMonthlyCalendarCode = function() {
	var vCode = "";
	var vHeader_Code = "";
	var vData_Code = "";
	
	// Begin Table Drawing code here..

	vCode = vCode + "<TABLE WIDTH='100%' BORDER='1'>";
	
	vHeader_Code = this.cal_header();
	vData_Code = this.cal_data();
	vCode = vCode + vHeader_Code + vData_Code;
	
	vCode = vCode + "</TABLE>";
	
	return vCode;
}

Calendar.prototype.show = function() {
	var vCode = "";
	
	this.gWinCal.document.open();

	// Setup the page...
	this.wwrite("<html>");
	this.wwrite("<head><title>Calendar</title>");
	this.wwrite("<LINK REL=STYLESHEET TYPE='text/css' HREF='"+CSSFILE+"'>");
	this.wwrite("</head>");

	this.wwrite("<body onblur='self.focus();' class='Calendar'>");
	this.wwriteA("<STRONG>");
	this.wwriteA(this.gMonthName + " " + this.gYear);
	this.wwriteA("</STRONG><BR>");

	// Show navigation buttons
	var prevMMYYYY = Calendar.calc_month_year(this.gMonth, this.gYear, -1);
	var prevMM = prevMMYYYY[0];
	var prevYYYY = prevMMYYYY[1];

	var nextMMYYYY = Calendar.calc_month_year(this.gMonth, this.gYear, 1);
	var nextMM = nextMMYYYY[0];
	var nextYYYY = nextMMYYYY[1];
	
	this.wwrite("<TABLE WIDTH='100%' BORDER=1 CELLSPACING=0 CELLPADDING=0 >");
	this.wwrite("<TR>\n\t<TD class='header'><A HREF=\"" +
			"javascript:window.opener.Build('"+this.gReturnSuffix +
			"', '" + this.gMonth + "', '" + (parseInt(this.gYear)-1) + "');" +
			"\">&lt;&lt;</A></TD>");
	this.wwrite("\t<TD class='header'><A HREF=\"" +
		"javascript:window.opener.Build('" + this.gReturnSuffix +
		"', '" + prevMM + "', '" + prevYYYY + "');" +
		"\">&lt;</A></TD>");
//	this.wwrite("\t<TD class='header'><A HREF=\"javascript:window.print();\">Print</A></TD>");
	this.wwrite("\t<TD class='header'>&nbsp;</TD>");
	this.wwrite("\t<TD class='header'><A HREF=\"" +
		"javascript:window.opener.Build('" + this.gReturnSuffix +
		"', '" + nextMM + "', '" + nextYYYY + "');" +
		"\">&gt;</A></TD>");
	this.wwrite("\t<TD class='header'><A HREF=\"" +
		"javascript:window.opener.Build('" + this.gReturnSuffix +
		"', '" + this.gMonth + "', '" + (parseInt(this.gYear)+1) + "');" +
		"\">&gt;&gt;</A></TD>\n</TR>\n</TABLE><BR>");

	// Get the complete calendar code for the month..
	vCode = this.getMonthlyCalendarCode();
	this.wwrite(vCode);

	this.wwrite("</body></html>");
	this.gWinCal.document.close();
}

Calendar.prototype.wwrite = function(wtext) {
	this.gWinCal.document.writeln(wtext);
}

Calendar.prototype.wwriteA = function(wtext) {
	this.gWinCal.document.write(wtext);
}

Calendar.prototype.cal_header = function() {
	var vCode = "";
	vCode = vCode + "\n<TR>";
	vCode = vCode + "\n\t<TH WIDTH='14%' class='date'>Пн</TH>";
	vCode = vCode + "\n\t<TH WIDTH='14%' class='date'>Вт</TH>";
	vCode = vCode + "\n\t<TH WIDTH='14%' class='date'>Ср</TH>";
	vCode = vCode + "\n\t<TH WIDTH='14%' class='date'>Чт</TH>";
	vCode = vCode + "\n\t<TH WIDTH='14%' class='date'>Пт</TH>";
	vCode = vCode + "\n\t<TH WIDTH='16%' class='date'>Сб</TH>";
	vCode = vCode + "\n\t<TH WIDTH='14%' class='date'>Вс</TH>";
	vCode = vCode + "\n</TR>";
	return vCode;
}

Calendar.prototype.cal_data = function() {
	var vDate = new Date();
	vDate.setDate(1);
	vDate.setMonth(this.gMonth);
	vDate.setFullYear(this.gYear);

	var vDay=1;
	var vLastDay=Calendar.get_daysofmonth(this.gMonth, this.gYear);
	var vOnLastDay=0;

	var vFirstDay=vDate.getDay();
	if(vFirstDay == 0){ vFirstDay=6; }
	else{ vFirstDay--; }

	/*
	Get day for the 1st of the requested month/year..
	Place as many blank cells before the 1st day of the month as necessary. 
	*/

	var vCode = "<TR>";
	for (i=0; i < vFirstDay; i++) {
		vCode = vCode + "\n\t<TD WIDTH='14%'" + this.write_weekend_string(i) + ">&nbsp;</TD>";
	}

	// Write rest of the 1st week
	for (j=vFirstDay; j<7; j++) {
		vCode = vCode + "\n\t<TD WIDTH='14%'" + this.write_weekend_string(j) + ">" + 
			"<A HREF='#' " + "onClick=\""+
			"opener.set_value_to_res_field('"+this.gReturnSuffix+"','"+vDay+"','"+this.gMonth+"','"+this.gYear+"'); "+
			"window.close();\">" +
				this.format_day(vDay) + 
			"</A>" + 
			"</TD>";
		vDay=vDay + 1;
	}
	vCode = vCode + "\n</TR>";

	// Write the rest of the weeks
	for (k=2; k<7; k++) {
		vCode = vCode + "\n<TR>";

		for (j=0; j<7; j++) {
			vCode = vCode + "\n\t<TD WIDTH='14%'" + this.write_weekend_string(j) + ">" + 
			"<A HREF='#' " + "onClick=\""+
			"opener.set_value_to_res_field('"+this.gReturnSuffix+"','"+vDay+"','"+this.gMonth+"','"+this.gYear+"'); "+
			"window.close();\">" +
				this.format_day(vDay) + 
			"</A>" + 
			"\n\t</TD>";
			vDay=vDay + 1;

			if (vDay > vLastDay) {
				vOnLastDay = 1;
				break;
			}
		}

		if (j == 6)
			vCode = vCode + "\n</TR>";
		if (vOnLastDay == 1)
			break;
	}
	
	// Fill up the rest of last week with proper blanks, so that we get proper square blocks
	for (m=1; m<(7-j); m++) {
		vCode = vCode + "\n\t<TD WIDTH='14%'" + this.write_weekend_string(j+m) + ">&nbsp;</TD>";
	}

	return vCode;
}

Calendar.prototype.format_day = function(vday) {
	var vNowDay = gNow.getDate();
	var vNowMonth = gNow.getMonth();
	var vNowYear = gNow.getFullYear();

	if (vday == vNowDay && this.gMonth == vNowMonth && this.gYear == vNowYear)
		return ("<STRONG class='today'>" + vday + "</STRONG>");
	else
		return (vday);
}

Calendar.prototype.write_weekend_string = function(vday) {
	var i;

	// Return special formatting for the weekend day.
	for (i=0; i<weekend.length; i++) {
		if (vday == weekend[i])
			return (" class='weekend' ");
	}
	
	return " class='date' ";
}

function Build( suffix, month, year ) {
	var p_WinCal = ggWinCal;
	CurrentCalendar = new Calendar( suffix, p_WinCal, month, year );
	CurrentCalendar.show();
}

function Destroy(  ) {
	CurrentCalendar = null;
}


function show_calendar(form, suffix) {
	if( !form || !suffix ){ return; }
   var month; var year;
   if( ResFormFieldType == 'input' ){
      var date = get_value_from_input( eval( "form.date" + suffix  ) );
      if( typeof( date ) == 'undefined' ){
        date = get_default_values();
      }
      if( typeof( date ) != 'undefined' && date.length == 3 ){
        year = date[0]*1;
        month = date[1]*1;
      }
   }else{ // 'select' is default
	   month = get_value_from_select( eval("form.mm"+suffix));
	   year = get_value_from_select( eval("form.yy"+suffix));
//      if( typeof month != "undefined"){ month--; }
   }

	if( typeof month == "undefined"){ month = gNow.getMonth(); }
   else{ month--; }
	if( typeof year  == "undefined"){ year = gNow.getFullYear(); }

/*
		month : 0-11 for Jan-Dec; 12 for All Months.
		year	: 4-digit year
*/
	if ((form == document.forms.users_statistics ) || (form == document.forms.users_statistics_expert )) {vWinCal = window.open("", "Calendar", "width=250,height=190,status=no,resizable=no,top=240,left=100"); }
  else {vWinCal = window.open("", "Calendar", "width=250,height=180,status=no,resizable=no,top=240,left=730");}
	vWinCal.focus();
	vWinCal.opener = self;

	ggWinCal = vWinCal;
	ReturnForm = form;

	Build( suffix, new String(month), new String(year) );
}

function get_value_from_input( field ){
   var mask = /(\d{4})\D(\d{1,2})\D(\d{1,2})/;
   if( !mask.test( field.value ) ){ return; }
   var res = new Array( RegExp.$1, RegExp.$2, RegExp.$3);
   return res;
}

function get_value_from_select( select )
{
	if( !select ){return;}
	var I = select.selectedIndex;
	if( I == 0 ){return;}
	var val = parseInt( (select.options[ I ].value)?select.options[ I ].value:select.options[ I ].text );
	if( isNaN(val) ){ val = 0;}
	return val;
}

function get_default_values(){
  var today = new Date();
  return new Array( today.getFullYear() , today.getMonth()+1, today.getDate() );
}

function set_value_to_res_field( suffix, day, month, year){
   if( !CurrentCalendar.gReturnForm ){ return false; } 
   if( ResFormFieldType == 'input' ){
      var field = eval( "CurrentCalendar.gReturnForm.date"+suffix );
      month++;
      field.value = year + '-' + format_number_to_0d_string( month )  + 
                           '-' + format_number_to_0d_string( day );
   }else{ // 'select' is default
      SetFormInDate( ReturnForm, suffix, day, month, year);
      Destroy();
   }
   return false;
}


function format_number_to_0d_string( n ){
   if( n < 10 ){ return "0"+n; }
   return n;
}

//function set_value_to_select( suffix, day, month, year){
//	if( !CurrentCalendar.gReturnForm ){ return false; } 
//	SetFormInDate( ReturnForm, suffix, day, month, year)
//	Destroy();
//	return false;
//}
