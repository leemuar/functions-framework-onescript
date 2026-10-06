# functions-framework-onescript

Реализация [Functions Framework](https://github.com/GoogleCloudPlatform/functions-framework) для
[OneScript](https://oscript.io). Превращает обычный файл OneScript с экспортной функцией в HTTP-сервер,
следующий тому же контракту запросов/ответов, что и официальные реализации Google (Node.js, Python, Go,
Java, ...) — благодаря этому одна и та же функция может выполняться локально, в контейнере или в любом
облаке, где можно запустить контейнер с HTTP-сервером (Google Cloud Run, Yandex Cloud Serverless
Containers и т.п.).

Поддерживаются два типа сигнатур функций:

| Тип сигнатуры | Аннотация             | Форма функции                  |
|----------------|------------------------|---------------------------------|
| `http`          | `&HttpFunction`        | `Процедура(Запрос, Ответ)`       |
| `cloudevent`    | `&CloudEventFunction`  | `Процедура(Событие)`             |

## Требования

OneScript **2.1.0 или новее**, по двум причинам:

- Встроенный класс `ВебСервер`, на котором держится HTTP-сервер фреймворка, появился в движке только
  начиная с версии **2.0**.
- В версиях до **2.1.0** есть баг в читателе/писателе JSON, который на round-trip незаметно теряет
  завершающий ноль в строках-датах с точностью до миллисекунд (например, `.230Z` превращается в `.23Z`),
  когда такая строка вложена внутрь передаваемого насквозь объекта. Для `cloudevent`-функций это
  означает порчу данных события.

## Установка

```bash
opm install functions-framework-onescript
```

Помимо файлов библиотеки, это регистрирует в системе команду `functions-framework`
(алиас для `oscript server.os`).

## Использование

Укажите фреймворку файл сценария и, при необходимости, какую экспортную функцию выполнять:

```bash
functions-framework --source my-function.os --target myFunction --port 8080
```

У каждого флага есть эквивалентная переменная окружения, которая используется, если флаг не передан:

| Флаг               | Переменная окружения       | Значение по умолчанию |
|---------------------|------------------------------|--------------------------|
| `--source`           | `FUNCTION_SOURCE`            | `main.os`                 |
| `--target`           | `FUNCTION_TARGET`            | *(см. ниже)*              |
| `--signature-type`   | `FUNCTION_SIGNATURE_TYPE`    | `http`                    |
| `--port`             | `PORT`                       | `8080`                    |

Переменная `PORT` — стандартный контракт serverless-контейнеров (Cloud Run, Yandex Serverless
Containers), поэтому готовый контейнер с фреймворком запускается там без дополнительной настройки.

## Какая функция выполняется

Фреймворк выбирает функцию для выполнения в таком порядке приоритета:

1. **Аннотация** — экспортная функция, помеченная `&HttpFunction` или `&CloudEventFunction`,
   используется автоматически, и по ней же определяется тип сигнатуры (поэтому
   `--signature-type` / `FUNCTION_SIGNATURE_TYPE` можно не указывать). В сценарии может быть только одна
   аннотированная функция.
2. **`--target` / `FUNCTION_TARGET`** — выполняется указанная экспортная функция, а тип сигнатуры берётся
   из `--signature-type` / `FUNCTION_SIGNATURE_TYPE` (по умолчанию `http`).
3. **По умолчанию** — если сценарий экспортирует функцию с именем `main`, используется она, с типом
   сигнатуры `http`.

## Примеры

**HTTP-функция** ([examples/hello-world-http.os](examples/hello-world-http.os)):

```bsl
Процедура main( Запрос, Ответ ) Экспорт
	html = "<h1>Hello, Function Framework for OneScript!</h1>";
	Буфер = ПолучитьБуферДвоичныхДанныхИзСтроки( html );
	Ответ.КодСостояния = 200;
	Ответ.Тело.Записать( Буфер, 0, Буфер.Размер );
КонецПроцедуры
```

**CloudEvent-функция:**

```bsl
&CloudEventFunction
Процедура HandleEvent( Событие ) Экспорт
	// Событие - Соответствие с атрибутами CloudEvent: specversion, type, source, id, time, data ...
КонецПроцедуры
```

Функция получает CloudEvent как в structured-режиме (`Content-Type: application/cloudevents+json`),
так и в binary-режиме (атрибуты в заголовках `Ce-*`). Успешный вызов возвращает `204`, ошибка разбора
запроса — `400`, исключение в функции — `500`.

## Проверка на соответствие контракту (conformance)

[conformance-http.os](conformance-http.os) и [conformance-cloudevent.os](conformance-cloudevent.os) —
минимальные целевые сценарии для запуска тестового клиента Google
[functions-framework-conformance](https://github.com/GoogleCloudPlatform/functions-framework-conformance)
против этого фреймворка, например:

```bash
client -type=http       -buildpacks=false -cmd="oscript server.os --source conformance-http.os"
client -type=cloudevent -validate-mapping=false -buildpacks=false -cmd="oscript server.os --source conformance-cloudevent.os"
```

Флаг `-validate-mapping=false` нужен потому, что конвертация legacy-событий Google Cloud
(Pub/Sub, Storage, Firestore и т.д.) в CloudEvent и обратно пока не реализована.
