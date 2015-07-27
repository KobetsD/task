#!C:\strawberry\perl\bin\perl

#Скрипт получает данные из Calk.htm страницы, обрабатывает их, и возвращает изменения

use strict;
use warnings;

use CGI qw(meta);
use CGI::Carp qw(fatalsToBrowser); #сообщения о фатальных ошибках будут отображаться в броузере

my $q = new CGI;

#---------------------Методы для печать начальных и завершающих html тегов--------------------
# print $q->header(-charset=>'utf-8');#Печать страндартного тега <head>
# print $q->start_html(
					# -title=>'Параметры',
					# -style=>{'src'=>'http://localhost/style/style.css'}
					# );#Дополнение тега <head> информацией

#print $q->end_html;#Печать тегов </body></html>
#----------------------------------------------------------------------------------------------

my $value=$q->param("textfield1");#Получение в виде строки значения параметра textfield, переданного из Calc.htm
$value=eval $value;#Исполнение полученного выражения
#$value=$q->referer."?".$q->query_string;#Полный URL с которого пришел пользователь
$q->param("textfield2"=>$value);#Присваивание в параметр textfield результат работы кода

my $URL='http://localhost/draft/Calceval.htm?'.$q->query_string;#Сшивание итогового URL

print $q->redirect($URL);#Перенаправление обратно