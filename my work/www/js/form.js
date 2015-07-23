var undefined = "-1";

function getCurrentYear()
{
	date = new Date();
	year = date.getYear();
	if( year < 1000 )
		year = year + 1900;
	return ( year.toString() );
}

function getCurrentMonth()
{
	date = new Date();
	month = date.getMonth() + 1;
	month = month < 10 ? "0" + month.toString() : month;
	return ( month.toString() );
}

function getCurrentDay()
{
	date = new Date();
	day = date.getDate();
	day = day < 10 ? "0" + day.toString() : day;
	return ( day.toString() );
}

function setOption( select_object, value ) {
	if( value == undefined ) {
		return true;
	}
	for ( var i = 0; i < select_object.length; i++ ) {
		if( value == select_object.options[i].value ) {
			select_object.options[i].selected=true;
			return true;
		}
	}
	return false;
}

function setCheckBox( checkbox, value ) {
	if( value == undefined) {
		return true;
	}
	if( value == "1" ) {
		checkbox.checked = true;
		return true;
	}
	if( value == "0" ) {
		checkbox.checked = false;
		return true;
	}
	return false;
}

function setCheckBoxByValue( checkbox, value, set_value ) {
	for( i = 0; i < checkbox.length; i++ ) {
		if( checkbox[i].value == value ) {
			return setCheckBox( checkbox[i], set_value );
		}
	}
//	alert ( checkbox.checked );
}


function setRadioButton( radio, value ) {
	if( value == undefined) {
	}

	for ( var i = 0; i < radio.length; i++ ) {
		if( radio[i].value == value ) {
			radio[i].checked = true;
			return true;
		}
	}
	return false;
}

function getRadioButtonValue( radio ) {
	for ( var i = 0; i < radio.length; i++ ) {
		if( radio[i].checked == true ) {
			return radio[i].value;
		}
	}
	return false;
}




function setText( Text, value )
{
	if( value == undefined ) {
		return true;
	}
	Text.value = value;
	return true;
}

1;
