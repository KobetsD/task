function ReadCookie(name)
{
	var num = document.cookie.length;
	name = name + "=";
	var len = name.length;
	var x=0;
	while( x <= num ) {
		var y = ( x+ len);
		if( document.cookie.substring(x,y)  == name )
			return ( extractCookieValue( y ) );
		x = document.cookie.indexOf( " ", x ) + 1;
		if( x == 0 )
			break;
	} 
	return null;
}

function extractCookieValue( val ) 
{
	if( ( end = document.cookie.indexOf( ";", val ) ) == -1 ) {
		end = document.cookie.length;
	} 
	return unescape( document.cookie.substring( val, end ) );
}
