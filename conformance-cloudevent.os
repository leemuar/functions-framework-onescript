
&CloudEventFunction
Процедура CloudEventConformance( Событие ) Экспорт

    Запись = Новый ЗаписьJSON();
    Запись.ОткрытьФайл( "function_output.json" );
    ЗаписатьJSON( Запись, Событие );
    Запись.Закрыть();

КонецПроцедуры
