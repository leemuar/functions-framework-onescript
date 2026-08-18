# functions-framework-onescript

Реализация [Functions Framework](https://github.com/GoogleCloudPlatform/functions-framework) для
[OneScript](https://oscript.io). Превращает обычный файл OneScript с экспортной функцией в HTTP-сервер,
следующий тому же контракту запросов/ответов, что и официальные реализации Google (Node.js, Python, Go,
Java, ...) — благодаря этому одна и та же функция может выполняться локально, в контейнере или на
Cloud Run / Cloud Functions.

Поддерживаются три типа сигнатур функций:

| Тип сигнатуры     | Аннотация              | Форма функции                                |
|--------------------|-------------------------|------------------------------------------------|
| `http`              | `&HttpFunction`         | `Процедура(Запрос, Ответ)`                      |
| `cloudevent`        | `&CloudEventFunction`   | `Процедура(Событие)`                            |
| `event` (legacy)    | `&BackgroundFunction`   | `Процедура(Данные, Контекст)`                   |

## Требования

OneScript **2.1.0 или новее**. В более ранних версиях движка есть баг в читателе/писателе JSON,
который на round-trip незаметно теряет завершающий ноль в строках-датах с точностью до миллисекунд
(например, `.230Z` превращается в `.23Z`), когда такая строка вложена внутрь передаваемого насквозь
объекта — это портит произвольные данные события (в частности, метки времени Cloud Storage/Firestore)
и исправлено в версии 2.1.0.

## Установка

```bash
opm install functions-framework-onescript
```

Помимо файлов библиотеки, это регистрирует команду `functions-framework-onescript` (алиас для
`oscript server.os`).

## Использование

Укажите фреймворку файл сценария и, при необходимости, какую экспортную функцию выполнять:

```bash
oscript server.os --source my-function.os --target myFunction --port 8080
```

У каждого флага есть эквивалентная переменная окружения, которая используется, если соответствующий
флаг не передан:

| Флаг                  | Переменная окружения          | Значение по умолчанию |
|------------------------|---------------------------------|--------------------------|
| `--source`               | `FUNCTION_SOURCE`               | `main.os`                  |
| `--target`               | `FUNCTION_TARGET`               | *(см. ниже)*                 |
| `--signature-type`       | `FUNCTION_SIGNATURE_TYPE`       | `http`                       |
| `--port`                 | `PORT`                          | `8080`                       |

## Какая функция выполняется

Фреймворк выбирает функцию для выполнения в следующем порядке приоритета:

1. **Аннотация** — экспортная функция, помеченная `&HttpFunction`, `&CloudEventFunction` или
   `&BackgroundFunction`, используется автоматически, и по ней же определяется тип сигнатуры (поэтому
   `--signature-type`/`FUNCTION_SIGNATURE_TYPE` можно не указывать). В сценарии может быть только одна
   аннотированная функция.
2. **`--target` / `FUNCTION_TARGET`** — выполняет указанную экспортную функцию, используя
   `--signature-type` / `FUNCTION_SIGNATURE_TYPE` (по умолчанию `http`), чтобы понять, как её вызывать.
3. **По умолчанию** — если сценарий экспортирует функцию с именем `main`, используется она, с типом
   сигнатуры `http`.

## Примеры

**HTTP-функция** ([examples/hello-world-http.os](examples/hello-world-http.os)):

```
Процедура main( Запрос, Ответ ) Экспорт
	html = "<h1>Hello, Function Framework for OneScript!</h1>";
	Буфер = ПолучитьБуферДвоичныхДанныхИзСтроки( html );
	Ответ.КодСостояния = 200;
	Ответ.Тело.Записать( Буфер, 0, Буфер.Размер );
КонецПроцедуры
```

**CloudEvent-функция:**

```
&CloudEventFunction
Процедура HandleEvent( Событие ) Экспорт
	// Событие - Соответствие с полями specversion/type/source/id/time/data
КонецПроцедуры
```

**Legacy event (background)-функция:**

```
&BackgroundFunction
Процедура HandleLegacyEvent( Данные, Контекст ) Экспорт
	// Контекст - Соответствие с полями eventId/timestamp/eventType/resource
КонецПроцедуры
```

Обработчик `cloudevent` также принимает тела событий в legacy-формате (как вариант `{data, context}`,
так и плоский формат GCF background-событий) и конвертирует их в формат CloudEvent на входе, включая
конвертацию `source`/`subject`/`type` для каждого сервиса — Cloud Storage, Pub/Sub, Firestore,
Firebase Auth и Firebase Realtime Database.

## Тестирование на соответствие контракту (conformance)

[conformance-http.os](conformance-http.os), [conformance-cloudevent.os](conformance-cloudevent.os) и
[conformance-legacyevent.os](conformance-legacyevent.os) — минимальные целевые сценарии для запуска
тестового клиента Google
[functions-framework-conformance](https://github.com/GoogleCloudPlatform/functions-framework-conformance)
против этого фреймворка, по одному на каждый тип сигнатуры, например:

```bash
client -type=http       -cmd="oscript server.os --source conformance-http.os"
client -type=cloudevent -cmd="oscript server.os --source conformance-cloudevent.os" -validate-mapping
client -type=legacyevent -cmd="oscript server.os --source conformance-legacyevent.os"
```

## Публикация

У пакета пока нет файла LICENSE — добавьте его перед публикацией в открытый доступ на
[hub.oscript.io](https://hub.oscript.io).

```bash
opm build --mf ./packagedef .
opm push -f ./functions-framework-onescript-0.1.0.ospx --token <ваш-токен-hub.oscript.io> -c stable
```
