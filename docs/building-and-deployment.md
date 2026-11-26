# Настройка Building & Deployment

[← Вернуться к основной документации](../README.md#building-and-deployment)

Pipeline `2: Building & Deployment` предназначен для автоматизации сборки контейнерного образа приложения, проверки его безопасности, формирования SBOM, публикации в контейнерном реестре и цифрового подписания.

Pipeline автоматически запускается после успешного слияния Pull Request в ветку `preprod` и прохождения проверок обновлённой ветки.



<a name="toc"></a>

## Содержание

- [1. Создание Build Configuration](#create-build-configuration)
- [2. Подключение VCS Root](#vcs-root)
- [3. Настройка подключения к Docker Hub](#docker-registry)
- [4. Настройка Snapshot Dependency](#snapshot-dependency)
- [5. Настройка Build Trigger](#build-trigger)
- [6. Настройка Build Steps](#build-steps)
  - [6.1. Build](#build)
  - [6.2. Trivy Image Scan](#trivy-image-scan)
  - [6.3. Generate SBOM](#generate-sbom)
  - [6.4. Upload SBOM to Dependency-Track](#upload-sbom)
  - [6.5. Push](#push)
  - [6.6. Cosign Sign & Verify](#cosign-sign-verify)

---

<a name="create-build-configuration"></a>

## 1. Создание Build Configuration

**Шаг 1. Добавление Build Configuration**

Перейдите в `Administration → Projects → global`.

Нажмите `Create build configuration` и выберите `Manually`.

**Шаг 2. Настройка параметров**

| Параметр | Значение |
|---|---|
| Name | `2: Building & Deployment` |
| Build configuration type | `Regular` |

Остальные параметры оставьте по умолчанию.

**Шаг 3. Сохранение**

Нажмите `Create`.


[← Вернуться к основной документации](../README.md#building-and-deployment) | [↑ К содержанию](#toc)

---

<a name="vcs-root"></a>

## 2. Подключение VCS Root

Для Pipeline `2: Building & Deployment` создадим отдельный VCS Root, который будет отслеживать изменения только в ветке `preprod`.

**Шаг 1. Создание VCS Root**

Перейдите в `Administration → Projects → global → VCS Roots`.

Нажмите `Create VCS root` и выберите тип `Git`.

**Шаг 2. Настройка параметров**

| Параметр | Значение |
|---|---|
| VCS root name | `Building & Development vcs` |
| VCS root ID | `Global_BuildingDevelopmentVcs` |
| Fetch URL | `https://github.com/<github-owner>/<github-repository>.git` |
| Default branch | `refs/heads/preprod` |
| Branch specification | Оставить пустым |
| Authentication method | `Password / personal access token` |
| Username | `<github-username>` |
| Password / access token | GitHub Personal Access Token |

Поле `Branch specification` оставляем пустым, поскольку Pipeline должен работать только с веткой `preprod`.

**Шаг 3. Проверка подключения**

Нажмите `Test connection` и убедитесь, что TeamCity успешно подключается к GitHub-репозиторию.

Нажмите `Save`.

**Шаг 4. Подключение VCS Root к Build Configuration**

1. Перейдите в `global → 2: Building & Deployment → Version Control`.
2. Нажмите `Attach VCS root`.
3. Выберите созданный `Building & Development vcs`.
4. Сохраните изменения.

Остальные параметры оставьте по умолчанию.

Таким образом, исходный код для сборки контейнерного образа будет загружаться из ветки `preprod`.


[← Вернуться к основной документации](../README.md#building-and-deployment) | [↑ К содержанию](#toc)

---

<a name="docker-registry"></a>

## 3. Настройка подключения к Docker Hub

Для публикации контейнерных образов необходимо настроить подключение TeamCity к контейнерному реестру.

В данном проекте используется Docker Hub, однако аналогичным образом можно настроить подключение к другому совместимому контейнерному реестру.

**Шаг 1. Создание подключения к контейнерному реестру**

Перейдите в `Administration → Projects → global → Connections`.

Нажмите `Add Connection` и выберите `Docker Registry`.

Укажите адрес контейнерного реестра, имя пользователя и токен доступа с необходимыми правами для загрузки и публикации контейнерных образов.

Сохраните подключение.

**Шаг 2. Добавление Build Feature**

Перейдите в `global → 2: Building & Deployment → Build Features`.

Нажмите `Add build feature` и выберите `Docker Registry Connections`.

Нажмите `Add registry connection` и выберите ранее созданное подключение к контейнерному реестру.

Параметр `On server clean-up, delete pushed Docker images from registry` оставьте отключённым, чтобы при автоматической очистке истории сборок TeamCity не удалял опубликованные контейнерные образы из реестра.

Нажмите `Save`.

**Как работает Docker Registry Connections**

Перед запуском сборки TeamCity автоматически выполняет аутентификацию в указанном контейнерном реестре.

Это позволяет:

- Загружать базовые контейнерные образы.
- Публиковать собранные контейнерные образы.
- Выполнять операции подписания образов с помощью Cosign.
- Отслеживать опубликованные контейнерные образы через отдельную вкладку в интерфейсе сборки.

При таком подходе нет необходимости добавлять команду `docker login` в Build Steps или хранить учётные данные непосредственно в скриптах Pipeline.


[← Вернуться к основной документации](../README.md#building-and-deployment) | [↑ К содержанию](#toc)

---

<a name="snapshot-dependency"></a>

## 4. Настройка Snapshot Dependency

Для обеспечения согласованности Git-ревизий между Pipeline необходимо настроить **Snapshot Dependency**.

Это позволяет собирать контейнерный образ из той же ревизии исходного кода, которая успешно прошла проверки качества и безопасности в `1: PR code reviewer`.

**Шаг 1. Добавление Snapshot Dependency**

Перейдите в `global → 2: Building & Deployment → Dependencies`.

Нажмите `Add new snapshot dependency` и выберите `1: PR code reviewer`.

**Шаг 2. Настройка параметров**

| Параметр | Значение |
|---|---|
| Enforce revisions synchronization | Включено |
| Do not run new build if there is a suitable one | Включено |
| Only use successful builds from suitable ones | Включено |
| Run build on the same agent | Отключено |
| On failed dependency | `Cancel build` |
| On failed to start/canceled dependency | `Mark build as failed to start` |

**Назначение основных параметров:**

- `Enforce revisions synchronization` — обеспечивает синхронизацию ревизий исходного кода между сборками.
- `Do not run new build if there is a suitable one` — позволяет повторно использовать подходящую сборку без повторного выполнения проверок.
- `Only use successful builds from suitable ones` — разрешает повторное использование только успешных сборок.
- `On failed dependency: Cancel build` — предотвращает выполнение Pipeline при неуспешном завершении зависимой сборки.
- `On failed to start/canceled dependency: Mark build as failed to start` — предотвращает запуск Pipeline, если зависимая сборка была отменена или не смогла запуститься.

**Шаг 3. Сохранение**

Нажмите `Save`.

После сохранения обе Build Configurations будут объединены в единую **Build Chain**.

Настроенная зависимость обеспечивает согласованность Git-ревизий между Pipeline, гарантируя, что контейнерный образ будет собран именно из той ревизии исходного кода, которая успешно прошла проверки качества и безопасности.


[← Вернуться к основной документации](../README.md#building-and-deployment) | [↑ К содержанию](#toc)

---

<a name="build-trigger"></a>

## 5. Настройка Build Trigger

Для автоматического запуска Pipeline `2: Building & Deployment` используется **Finish Build Trigger**.

Pipeline должен запускаться после слияния Pull Request в ветку `preprod` и успешного завершения проверки обновлённой ветки в `1: PR code reviewer`.

**Шаг 1. Добавление Build Trigger**

Перейдите в `global → 2: Building & Deployment → Triggers`.

Нажмите `Add new trigger` и выберите `Finish Build Trigger`.

**Шаг 2. Настройка параметров**

| Параметр | Значение |
|---|---|
| Build configuration | `global / 1: PR code reviewer` |
| Trigger after successful build only | Включено |
| Branch filter | `+:<default>` |

Остальные параметры оставьте по умолчанию.

Параметр `Trigger after successful build only` разрешает автоматический запуск Pipeline только после успешного завершения указанной Build Configuration.

Фильтр `+:<default>` ограничивает срабатывание триггера сборками ветки `preprod`, исключая запуск Pipeline после проверки открытых Pull Requests.

**Шаг 3. Сохранение**

Нажмите `Save`.

**Последовательность запуска Pipeline**

1. Разработчик создаёт Pull Request в ветку `preprod`.
2. TeamCity запускает `1: PR code reviewer` для проверки Pull Request.
3. После успешного прохождения обязательных проверок Pull Request сливается в `preprod`.
4. TeamCity запускает `1: PR code reviewer` для проверки обновлённой ветки `preprod`.
5. После успешного завершения проверки автоматически запускается `2: Building & Deployment`.

Настроенный Finish Build Trigger определяет условия автоматического запуска Pipeline, а ранее настроенная Snapshot Dependency обеспечивает согласованность Git-ревизий между сборками.

Таким образом, сборка контейнерного образа выполняется из проверенной ревизии исходного кода ветки `preprod`.


[← Вернуться к основной документации](../README.md#building-and-deployment) | [↑ К содержанию](#toc)

---

<a name="build-steps"></a>

## 6. Настройка Build Steps

Перейдите в `global → 2: Building & Deployment → Build Steps`.

<a name="build"></a>

### 6.1. Build

На этом этапе выполняется сборка контейнерного образа приложения на основе `Dockerfile`, расположенного в корневом каталоге GitHub-репозитория.

**Шаг 1. Добавление Build Step**

Нажмите `Add build step` и выберите `Docker`.

**Шаг 2. Настройка параметров**

| Параметр | Значение |
|---|---|
| Step name | `Build` |
| Docker command | `build` |
| Dockerfile source | `File` |
| Dockerfile path | `Dockerfile` |
| Context folder | `.` |
| Image name:tag | `%IMAGE_NAME%:%build.vcs.number%` |
| Additional arguments | `--pull` |

Остальные параметры оставьте по умолчанию.

Аргумент `--pull` позволяет Docker проверять наличие более свежих версий базовых образов в контейнерном реестре при каждой сборке.

**Шаг 3. Настройка имени контейнерного образа**

В разделе `Parameters` создайте конфигурационный параметр:

| Параметр | Значение |
|---|---|
| Name | `IMAGE_NAME` |
| Kind | `Configuration parameter` |
| Value | `<docker-user>/<docker-repo>` |

Где:

- `<docker-user>` — имя пользователя или организации в Docker Hub.
- `<docker-repo>` — имя репозитория контейнерных образов.

Вынесение имени образа в отдельный параметр позволяет использовать его во всех последующих Build Steps без дублирования настроек.

**Формирование тега контейнерного образа**

В качестве тега используется Git commit SHA, получаемый через встроенный параметр TeamCity:

```text
%build.vcs.number%
```

Полное имя контейнерного образа формируется следующим образом:

```text
%IMAGE_NAME%:%build.vcs.number%
```

Использование Git commit SHA в качестве тега позволяет:

- Связать контейнерный образ с конкретной ревизией исходного кода.
- Обеспечить прослеживаемость между GitHub, TeamCity и контейнерным реестром.
- Идентифицировать версию приложения при развёртывании.
- Упростить выбор предыдущей версии приложения при необходимости отката.

**Шаг 4. Сохранение**

Нажмите `Save`.

После успешного выполнения шага контейнерный образ будет доступен локально на Build Agent для последующего сканирования, формирования SBOM и публикации в контейнерном реестре.


[← Вернуться к основной документации](../README.md#building-and-deployment) | [↑ К содержанию](#toc)

---

<a name="trivy-image-scan"></a>

### 6.2. Trivy Image Scan

На этом этапе выполняется сканирование собранного контейнерного образа с помощью Trivy перед его публикацией в Docker Hub.

Сканирование включает:

- **Vulnerabilities** — известные уязвимости в системных пакетах и зависимостях приложения.
- **Secrets** — потенциально конфиденциальные данные, содержащиеся в образе.
- **Misconfigurations** — небезопасные конфигурации, обнаруженные в поддерживаемых Trivy файлах.

**Шаг 1. Добавление Build Step**

Нажмите `Add build step` и выберите `Command Line`.

**Шаг 2. Настройка параметров**

| Параметр | Значение |
|---|---|
| Step name | `Trivy Image Scan` |
| Run | `Custom script` |

В поле `Custom script` добавьте следующий скрипт:

```bash
#!/usr/bin/env bash
set -euo pipefail

IMAGE="%IMAGE_NAME%:%build.vcs.number%"
REPORT_DIR="trivy-report"

mkdir -p "$REPORT_DIR"

echo "=== Generating Trivy JSON Report ==="

trivy image --scanners vuln,secret,misconfig --severity UNKNOWN,LOW,MEDIUM,HIGH,CRITICAL --format json --output "$REPORT_DIR/trivy-report.json" --exit-code 0 "$IMAGE"

echo "=== Generating Trivy HTML Report ==="

trivy convert --format template --template "@/usr/local/share/trivy/templates/html.tpl" --output "$REPORT_DIR/index.html" "$REPORT_DIR/trivy-report.json"

echo "=== Security Gate ==="

trivy image --scanners vuln --severity HIGH,CRITICAL --exit-code 1 "$IMAGE"

echo "Security Gate PASSED"
```

**Принцип работы скрипта**

Сканирование выполняется в несколько этапов:

1. **Генерация JSON-отчёта** — сканирование контейнерного образа на наличие уязвимостей, секретов и ошибок конфигурации. В отчёт включаются результаты всех уровней критичности.
2. **Генерация HTML-отчёта** — преобразование JSON-отчёта в HTML с помощью шаблона Trivy для последующего просмотра результатов в интерфейсе TeamCity.
3. **Security Gate** — проверка контейнерного образа на наличие уязвимостей уровней `HIGH` и `CRITICAL`.

**Условия прохождения Security Gate**

| Уровень критичности уязвимости | Результат |
|---|---|
| UNKNOWN | PASSED |
| LOW | PASSED |
| MEDIUM | PASSED |
| HIGH | FAILED |
| CRITICAL | FAILED |

При обнаружении хотя бы одной уязвимости уровня `HIGH` или `CRITICAL` Trivy завершает работу с кодом возврата `1`, что приводит к неуспешному завершению сборки и предотвращает выполнение последующих шагов Pipeline.

Обнаруженные секреты и ошибки конфигурации включаются в отчёт, но в рамках текущей конфигурации не являются блокирующими условиями Security Gate.

Отчёты формируются до выполнения Security Gate, что позволяет сохранить результаты сканирования даже при неуспешном завершении проверки.

**Шаг 3. Сохранение**

Нажмите `Save`.

**Шаг 4. Настройка публикации отчётов**

Перейдите в `global → 2: Building & Deployment → General Settings`.

В поле `Artifact paths` добавьте:

```text
trivy-report/** => trivy-report
```

Для параметра `Publish artifacts` выберите `Even if build fails`.

Это обеспечит доступность отчётов независимо от результата прохождения Security Gate.

После выполнения сборки в разделе `Artifacts` будут доступны следующие файлы:

| Файл | Назначение |
|---|---|
| `trivy-report/trivy-report.json` | Машиночитаемый отчёт сканирования |
| `trivy-report/index.html` | HTML-отчёт для просмотра результатов |

Таким образом, Security Gate предотвращает публикацию контейнерных образов, содержащих обнаруженные уязвимости уровней `HIGH` и `CRITICAL`.


[← Вернуться к основной документации](../README.md#building-and-deployment) | [↑ К содержанию](#toc)

---

<a name="generate-sbom"></a>

### 6.3. Generate SBOM
На этом этапе выполняется формирование **SBOM (Software Bill of Materials)** — перечня программных компонентов, входящих в состав контейнерного образа.

Для генерации SBOM используется Trivy, а результаты сохраняются в стандартизированном формате CycloneDX.

Наличие SBOM позволяет:

- Получить информацию о системных пакетах и зависимостях приложения.
- Отслеживать используемые компоненты и их версии.
- Определять наличие компонентов, в которых впоследствии могут быть обнаружены уязвимости.
- Обеспечить прозрачность состава программного обеспечения.
- Использовать результаты для аудита и анализа безопасности цепочки поставок программного обеспечения (Software Supply Chain Security).

**Шаг 1. Добавление Build Step**

Нажмите `Add build step` и выберите `Command Line`.

**Шаг 2. Настройка параметров**

| Параметр | Значение |
|---|---|
| Step name | `Generate SBOM` |
| Run | `Custom script` |

В поле `Custom script` добавьте следующий скрипт:

```bash
#!/usr/bin/env bash
set -euo pipefail

IMAGE="%IMAGE_NAME%:%build.vcs.number%"
REPORT_DIR="sbom-report"

mkdir -p "$REPORT_DIR"

echo "=== Generating CycloneDX SBOM ==="

trivy image --format cyclonedx --output "$REPORT_DIR/sbom.json" "$IMAGE"

echo "=== SBOM generated ==="

ls -lh "$REPORT_DIR/sbom.json"

echo "=== Number of components ==="

python3 -c 'import json; d=json.load(open("sbom-report/sbom.json")); print("Components:", len(d.get("components", [])))'
```

**Принцип работы скрипта**

1. Определяется имя контейнерного образа с использованием параметров `IMAGE_NAME` и `build.vcs.number`.
2. Создаётся каталог для хранения SBOM.
3. Trivy анализирует контейнерный образ и формирует SBOM в формате CycloneDX JSON.
4. В Build Log выводится информация о сформированном файле и его размере.
5. С помощью Python подсчитывается количество компонентов, включённых в SBOM.

Формирование SBOM выполняется после успешного прохождения Security Gate и до публикации контейнерного образа в Docker Hub.

**Шаг 3. Сохранение**

Нажмите `Save`.

**Шаг 4. Настройка публикации SBOM**

Перейдите в `global → 2: Building & Deployment → General Settings`.

В поле `Artifact paths` добавьте правило публикации SBOM, сохранив ранее настроенное правило публикации отчётов Trivy:

```text
trivy-report/** => trivy-report
sbom-report/** => sbom-report
```

Для параметра `Publish artifacts` оставьте ранее установленное значение `Even if build fails`.

После выполнения данного шага в разделе `Artifacts` будет доступен файл:

| Файл | Назначение |
|---|---|
| `sbom-report/sbom.json` | Перечень программных компонентов в формате CycloneDX JSON |

SBOM сохраняется в артефактах соответствующей сборки TeamCity, обеспечивая возможность анализа состава контейнерного образа для конкретной Git-ревизии.

В отличие от Trivy Image Scan, данный шаг предназначен для инвентаризации программных компонентов и не выполняет дополнительную проверку Security Gate.


[← Вернуться к основной документации](../README.md#building-and-deployment) | [↑ К содержанию](#toc)

---

<a name="upload-sbom"></a>

### 6.4. Upload SBOM to Dependency-Track

Данный Build Step предназначен для автоматической передачи сформированного SBOM в Dependency-Track.

Dependency-Track используется для централизованного анализа программных компонентов и непрерывного мониторинга уязвимостей после завершения CI/CD Pipeline.

Загрузка SBOM выполняется после шага `Generate SBOM` и перед публикацией контейнерного образа в Docker Hub.

#### 6.4.1. Настройка параметров TeamCity

Перейдите в раздел:

`Administration → Projects → global → 2: Building & Deployment → Parameters`

Добавьте следующие параметры:

| Name | Kind | Type | Value |
|---|---|---|---|
| `env.DTRACK_URL` | Environment variable | Text | `http://<dependency-track-host>:8081` |
| `env.DTRACK_PROJECT_NAME` | Environment variable | Text | `cicd-lab` |
| `env.DTRACK_API_KEY` | Environment variable | Password | API Key |

**DTRACK_URL**

Адрес API-сервера Dependency-Track.

Необходимо использовать адрес Backend API, а не Frontend.

**DTRACK_PROJECT_NAME**

Название проекта, под которым программные компоненты будут зарегистрированы в Dependency-Track.

**DTRACK_API_KEY**

API Key сервисной учётной записи TeamCity в Dependency-Track.

Для загрузки SBOM и автоматического создания проектов необходимы следующие разрешения:

- `BOM_UPLOAD`
- `PROJECT_CREATION_UPLOAD`

API Key необходимо хранить в TeamCity как параметр типа `Password`.

#### 6.4.2. Создание Build Step

Перейдите в раздел:

`Administration → Projects → global → 2: Building & Deployment → Build Steps`

Нажмите `Add build step`.

Укажите следующие параметры:

| Параметр | Значение |
|---|---|
| Runner type | Command Line |
| Step name | `Upload SBOM to Dependency-Track` |
| Execute step | Only if all previous steps were successful |
| Working directory | `%teamcity.build.checkoutDir%` |
| Run | Custom script |

#### 6.4.3. Скрипт загрузки SBOM

```bash
#!/usr/bin/env bash
set -euo pipefail
set +x

SBOM_FILE="sbom-report/sbom.json"
PROJECT_VERSION="%build.vcs.number%"

: "${DTRACK_URL:?DTRACK_URL is required}"
: "${DTRACK_PROJECT_NAME:?DTRACK_PROJECT_NAME is required}"
: "${DTRACK_API_KEY:?DTRACK_API_KEY is required}"

echo "=== Uploading SBOM to Dependency-Track ==="

if [[ ! -s "$SBOM_FILE" ]]; then
    echo "ERROR: SBOM file not found or empty: $SBOM_FILE"
    exit 1
fi

echo "Project: $DTRACK_PROJECT_NAME"
echo "Version: $PROJECT_VERSION"
echo "SBOM: $SBOM_FILE"
echo "Server: $DTRACK_URL"

RESPONSE=$(curl --silent --show-error --fail-with-body --connect-timeout 10 --max-time 120 --request POST "${DTRACK_URL%/}/api/v1/bom" --header "X-Api-Key: ${DTRACK_API_KEY}" --form "autoCreate=true" --form "projectName=${DTRACK_PROJECT_NAME}" --form "projectVersion=${PROJECT_VERSION}" --form "bom=@${SBOM_FILE};type=application/json")

TOKEN=$(echo "$RESPONSE" | python3 -c 'import json, sys; print(json.load(sys.stdin)["token"])')

echo "=== SBOM successfully submitted ==="
echo "Processing token: $TOKEN"
echo "Vulnerability analysis will be performed asynchronously."
```

#### 6.4.4. Принцип работы

Скрипт выполняет следующие действия:

1. Проверяет наличие обязательных переменных окружения.
2. Проверяет наличие и содержимое файла SBOM.
3. Использует Git commit SHA в качестве версии проекта.
4. Отправляет SBOM через REST API Dependency-Track.
5. Получает токен обработки SBOM из JSON-ответа.
6. Завершает Build Step после успешной передачи файла.

**Обработка ошибок и безопасность**

| Параметр | Назначение |
|---|---|
| `set -e` | Завершение скрипта при необработанной ошибке выполнения команды |
| `set -u` | Контроль использования неопределённых переменных |
| `set -o pipefail` | Контроль ошибок внутри цепочек команд |
| `set +x` | Отключение трассировки команд для предотвращения вывода API Key через shell tracing |
| `${VARIABLE:?message}` | Проверка наличия и непустого значения обязательной переменной |
| `[[ ! -s "$SBOM_FILE" ]]` | Проверка отсутствующего или пустого файла SBOM |
| `--fail-with-body` | Возврат ошибки при HTTP-ответах с кодом 400 и выше с сохранением тела ответа |
| `--connect-timeout 10` | Ограничение времени установления соединения до 10 секунд |
| `--max-time 120` | Ограничение общего времени выполнения HTTP-запроса до 120 секунд |
| `${DTRACK_URL%/}` | Удаление завершающего символа `/` из адреса сервера при его наличии |

Использование ограничений времени предотвращает длительное ожидание ответа при недоступности Dependency-Track.

API Key передаётся через HTTP-заголовок `X-Api-Key` и хранится в защищённом параметре TeamCity.

Для production-окружения рекомендуется использовать HTTPS, чтобы обеспечить шифрование API Key и передаваемых данных при сетевом взаимодействии.

**Dependency-Track REST API**

Для загрузки SBOM используется следующий API endpoint:

```text
POST /api/v1/bom
```

Параметры запроса:

| Параметр | Назначение |
|---|---|
| `autoCreate` | Автоматическое создание проекта и его версии при их отсутствии |
| `projectName` | Название проекта |
| `projectVersion` | Git commit SHA текущей сборки |
| `bom` | SBOM в формате CycloneDX JSON |

При успешной загрузке Dependency-Track возвращает JSON-ответ, содержащий токен обработки:

```json
{
    "token": "<processing-token>"
}
```

Получение токена подтверждает успешную передачу SBOM для последующей обработки.

Анализ программных компонентов и поиск уязвимостей выполняются асинхронно на стороне Dependency-Track.

Pipeline не ожидает завершения анализа и продолжает выполнение после успешной передачи SBOM.

#### 6.4.5. Версионирование проектов

Каждая успешно загруженная ревизия приложения представлена в Dependency-Track отдельной версией проекта.

```text
cicd-lab
├── <git-commit-sha-1>
├── <git-commit-sha-2>
├── <git-commit-sha-3>
└── ...
```

Такой подход позволяет:

- Отслеживать состав каждой версии приложения.
- Сравнивать программные компоненты между версиями.
- Анализировать появление новых уязвимостей.
- Сохранять историю результатов анализа.
- Отслеживать безопасность ранее опубликованных образов.

#### 6.4.6. Обработка результатов

Dependency-Track выполняет обработку SBOM и анализ программных компонентов асинхронно.

Успешное завершение Build Step означает, что SBOM был принят Dependency-Track, но не означает завершения анализа уязвимостей.

Pipeline не ожидает окончания анализа.

В текущей архитектуре используются два независимых механизма контроля безопасности:

| Компонент | Назначение | Блокирующая проверка |
|---|---|---|
| Trivy | Проверка контейнерного образа перед публикацией | Да |
| Dependency-Track | Непрерывный мониторинг программных компонентов | Нет |

При обнаружении уязвимостей в Dependency-Track Pipeline автоматически не блокируется.

При этом ошибка передачи SBOM в Dependency-Track приводит к неуспешному завершению Build Step и предотвращает выполнение последующего шага `Push`.

Таким образом, публикация контейнерного образа требует успешной передачи SBOM, но не зависит от результатов его асинхронного анализа.

#### 6.4.7. Проверка результата

После успешного выполнения Build Step откройте веб-интерфейс Dependency-Track:

`Projects → cicd-lab`

Выберите версию проекта, соответствующую Git commit SHA текущей сборки.

После завершения обработки SBOM будут доступны:

- Перечень программных компонентов.
- Версии используемых зависимостей.
- Обнаруженные уязвимости.
- Распределение уязвимостей по уровням критичности.
- Информация о лицензиях компонентов при наличии соответствующих данных.
- Risk Score.

Dependency-Track продолжает анализировать зарегистрированные компоненты независимо от выполнения CI/CD Pipeline, позволяя обнаруживать новые уязвимости в ранее собранных версиях приложения.

[← Вернуться к основной документации](../README.md#building-and-deployment) | [↑ К содержанию](#toc)

---

<a name="push"></a>

### 6.5. Push

На этом этапе выполняется публикация контейнерного образа в Docker Hub после успешного прохождения Security Gate, формирования и загрузки SBOM.

Для публикации используется ранее настроенное подключение к Docker Hub через `Docker Registry Connections`.

**Шаг 1. Добавление Build Step**

Нажмите `Add build step` и выберите `Docker`.

**Шаг 2. Настройка параметров**

| Параметр | Значение |
|---|---|
| Step name | `Push` |
| Docker command | `push` |
| Image name:tag | `%IMAGE_NAME%:%build.vcs.number%` |

Остальные параметры оставьте по умолчанию.

Для публикации используется то же имя и тег контейнерного образа, которые были определены на этапе `Build`.

Авторизация в Docker Hub выполняется автоматически средствами TeamCity благодаря ранее настроенному Build Feature `Docker Registry Connections`. Дополнительное выполнение команды `docker login` не требуется.

**Шаг 3. Сохранение**

Нажмите `Save`.

После успешного выполнения данного шага контейнерный образ будет доступен в Docker Hub:

```text
docker.io/<docker-user>/<docker-repo>:<git-commit-sha>
```

Публикация выполняется только при успешном завершении предыдущих Build Steps.


[← Вернуться к основной документации](../README.md#building-and-deployment) | [↑ К содержанию](#toc)

---

<a name="cosign-sign-verify"></a>

### 6.6. Cosign Sign & Verify

На этом этапе выполняется цифровое подписание опубликованного контейнерного образа с помощью Cosign и последующая проверка его подписи.

Использование цифровой подписи позволяет подтвердить подлинность контейнерного образа и обеспечить контроль его целостности в рамках Software Supply Chain Security.

**Шаг 1. Генерация ключей Cosign**

На компьютере с установленным Cosign выполните команду:

```bash
cosign generate-key-pair
```

В процессе генерации необходимо указать пароль для защиты приватного ключа.

В результате будут созданы два файла:

| Файл | Назначение |
|---|---|
| `cosign.key` | Приватный ключ для подписания контейнерных образов |
| `cosign.pub` | Публичный ключ для проверки цифровой подписи |

Приватный ключ и пароль необходимо хранить в защищённом месте. Не допускается их размещение в GitHub-репозитории.

Публичный ключ может распространяться свободно и использоваться внешними системами для проверки подписи контейнерных образов.

**Шаг 2. Настройка параметров TeamCity**

Перейдите в `global → 2: Building & Deployment → Parameters`.

Создайте следующие параметры:

| Name | Type | Value |
|---|---|---|
| `env.COSIGN_PRIVATE_KEY` | Password | Содержимое файла `cosign.key` |
| `env.COSIGN_PUBLIC_KEY` | Text | Содержимое файла `cosign.pub` |
| `env.COSIGN_PASSWORD` | Password | Пароль приватного ключа |

Префикс `env.` обеспечивает передачу параметров в Build Agent в качестве переменных окружения.

Приватный ключ и пароль должны иметь тип `Password`, чтобы ограничить их отображение в интерфейсе TeamCity и Build Log.

**Шаг 3. Добавление Build Step**

Перейдите в `Build Steps`.

Нажмите `Add build step` и выберите `Command Line`.

**Шаг 4. Настройка параметров**

| Параметр | Значение |
|---|---|
| Step name | `Cosign Sign & Verify` |
| Run | `Custom script` |

В поле `Custom script` добавьте следующий скрипт:

```bash
#!/usr/bin/env bash
set -euo pipefail
set +x

IMAGE="docker.io/%IMAGE_NAME%:%build.vcs.number%"
REPOSITORY="docker.io/%IMAGE_NAME%"

KEY_DIR="$(mktemp -d)"
chmod 700 "$KEY_DIR"

trap 'rm -rf "$KEY_DIR"' EXIT

printf '%s\n' "$COSIGN_PRIVATE_KEY" > "$KEY_DIR/cosign.key"
printf '%s\n' "$COSIGN_PUBLIC_KEY" > "$KEY_DIR/cosign.pub"

chmod 600 "$KEY_DIR/cosign.key"
chmod 644 "$KEY_DIR/cosign.pub"

echo "=== Resolving Docker image digest ==="

DIGEST="$(docker buildx imagetools inspect "$IMAGE" --format '{{.Manifest.Digest}}')"

if [[ ! "$DIGEST" =~ ^sha256:[a-f0-9]{64}$ ]]; then
    echo "ERROR: Invalid image digest: $DIGEST"
    exit 1
fi

IMAGE_REF="${REPOSITORY}@${DIGEST}"

echo "Image: $IMAGE_REF"

echo "=== Signing Docker image ==="

cosign sign --yes --key "$KEY_DIR/cosign.key" "$IMAGE_REF"

echo "=== Verifying Docker image signature ==="

cosign verify --key "$KEY_DIR/cosign.pub" "$IMAGE_REF"

echo "=== Signature verification successful ==="
```

**Принцип работы скрипта**

1. Создаётся временный каталог с ограниченными правами доступа.
2. Приватный и публичный ключи записываются во временные файлы из переменных окружения TeamCity.
3. С помощью Docker Buildx определяется digest опубликованного контейнерного образа.
4. Проверяется корректность формата полученного digest.
5. Выполняется подписание контейнерного образа приватным ключом Cosign.
6. Выполняется проверка цифровой подписи публичным ключом.
7. При завершении скрипта временный каталог с ключами автоматически удаляется.

**Подписание контейнерного образа по digest**

В отличие от тега контейнерного образа, который может быть перезаписан, digest является идентификатором конкретного содержимого образа.

Поэтому подписание выполняется не по тегу:

```text
docker.io/<docker-user>/<docker-repo>:<git-commit-sha>
```

а по digest:

```text
docker.io/<docker-user>/<docker-repo>@sha256:<digest>
```

Это обеспечивает привязку цифровой подписи к конкретному опубликованному образу независимо от последующих изменений тегов в контейнерном реестре.

**Безопасность хранения ключей**

В рамках текущей конфигурации предусмотрены следующие меры защиты:

- Хранение приватного ключа и пароля в защищённых параметрах TeamCity.
- Отключение трассировки команд с помощью `set +x`.
- Использование временного каталога с правами доступа `700`.
- Ограничение прав доступа к приватному ключу до `600`.
- Автоматическое удаление временных файлов при завершении скрипта.

**Шаг 5. Сохранение**

Нажмите `Save`.

При успешном выполнении данного шага в Build Log будет отображено сообщение:

```text
=== Signature verification successful ===
```

При возникновении ошибки получения digest, подписания или проверки цифровой подписи Pipeline завершится со статусом `FAILED`.

При этом необходимо учитывать, что контейнерный образ публикуется на предыдущем этапе `Push`. Ошибка подписания не приводит к автоматическому удалению уже опубликованного образа из Docker Hub.

Для предотвращения использования неподписанных контейнерных образов проверка цифровой подписи должна дополнительно выполняться на этапе развёртывания приложения.

[← Вернуться к основной документации](../README.md#building-and-deployment) | [↑ К содержанию](#toc)
