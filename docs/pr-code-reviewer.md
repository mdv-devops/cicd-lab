# PR Code Reviewer

[← Вернуться к основной документации](../README.md#pr-code-reviewer)

Перед настройкой Pipeline необходимо [создать проект TeamCity](teamcity.md#project-creation) и [настроить VCS Root](teamcity.md#vcs-root).

<a name="toc"></a>

## Содержание

- [1. Создание Build Configuration PR code reviewer](#create-build-configuration)
- [2. Подключение VCS Root к Build Configuration](#vcs-root)
- [3. Настройка Pull Requests Build Feature](#pull-requests)
- [4. Настройка Build Triggers](#build-triggers)
- [5. Настройка Commit Status Publisher](#commit-status-publisher)
- [6. Настройка Build Steps](#build-steps)
  - [6.1. SonarScanner Begin](#sonarscanner-begin)
  - [6.2. Restore](#restore)
  - [6.3. Build](#build)
  - [6.4. Test](#test)
  - [6.5. SonarScanner End](#sonarscanner-end)
  - [6.6. Coverage Report](#coverage-report)
  - [6.7. Trivy Dependency Scan](#trivy-dependency-scan)
- [7. Настройка Build Report Tabs](#build-report-tabs)
- [8. Проверка работы PR code reviewer](#pipeline-verification)

---

<a name="create-build-configuration"></a>

## 1. Создание Build Configuration `PR code reviewer`

Первая Build Configuration предназначена для автоматической проверки исходного кода перед объединением Pull Request.

**Шаг 1. Создание Build Configuration**

Откройте TeamCity и перейдите в настройки проекта:

`Administration → Projects → global → General`

В разделе `Build Configurations` нажмите `Create build configuration`.

Создайте новую конфигурацию со следующими параметрами:

| Параметр | Значение |
|---|---|
| Name | `1: PR code reviewer` |
| Build configuration ID | `PR_Code_Reviewer` |
| Description | Оставить пустым |
| Build configuration type | `Regular` |

Сохраните конфигурацию.

После создания она появится в списке `Build Configurations` проекта `global`.

[← Вернуться к интеграции с GitHub](../README.md#pr-github-integration) | [↑ К содержанию](#toc)

---

<a name="vcs-root"></a>

## 2. Подключение VCS Root к Build Configuration

После создания Build Configuration необходимо подключить к ней ранее настроенный VCS Root. Это позволит TeamCity получать исходный код приложения из GitHub.

**Шаг 1. Подключение VCS Root**

Откройте TeamCity и перейдите в:

`global → 1: PR code reviewer → Version Control`

Нажмите `Attach VCS root`.

В появившемся окне выберите ранее созданный VCS Root:

`cicd-lab-vcs`

Подтвердите подключение.

[← Вернуться к интеграции с GitHub](../README.md#pr-github-integration) | [↑ К содержанию](#toc)

---

<a name="pull-requests"></a>

## 3. Настройка Pull Requests Build Feature

Для автоматического обнаружения Pull Requests из GitHub необходимо добавить в Build Configuration специальный компонент **Pull Requests Build Feature**.

Он позволяет TeamCity отслеживать новые и обновлённые Pull Requests, получать информацию об их исходных и целевых ветках и использовать эти данные при выполнении сборок.

**Шаг 1. Добавление Pull Requests Build Feature**

Откройте TeamCity и перейдите в настройки Build Configuration:

`global → 1: PR code reviewer → Build Features`

Нажмите `Add build feature` и выберите `Pull Requests`.

**Шаг 2. Настройка подключения к GitHub**

Заполните следующие параметры:

| Параметр | Значение |
|---|---|
| VCS Root | `cicd-lab-vcs` |
| VCS hosting type | `GitHub` |
| Authentication Type | `Access token` |
| Token | GitHub Personal Access Token |

Для обращения к GitHub API используется токен доступа. Он необходим TeamCity для получения информации о Pull Requests.

Токен должен иметь необходимые разрешения для чтения Pull Requests и информации о репозитории. Хранить его следует в защищённых настройках TeamCity.

**Шаг 3. Настройка фильтрации Pull Requests**

В разделе `Pull Request Filtering` укажите:

| Параметр | Значение |
|---|---|
| By authors | `Everybody` |
| By source branch | Оставить пустым |
| By target branch | `refs/heads/preprod` |
| Ignore Drafts | Включено |

Назначение параметров:

- **By authors** — определяет, Pull Requests каких авторов будет обнаруживать TeamCity. Значение `Everybody` разрешает обнаружение PR от всех авторов.
- **By source branch** — фильтр исходных веток. Пустое поле означает отсутствие ограничений по названию ветки.
- **By target branch** — определяет целевую ветку Pull Request. В нашем случае TeamCity отслеживает PR, направленные в `preprod`.
- **Ignore Drafts** — исключает черновики Pull Requests из обнаружения. После перевода PR в состояние `Ready for review` он может быть обнаружен TeamCity.

**Важно:** при использовании публичного репозитория настройка `Everybody` требует особого внимания к безопасности Build Agent, поскольку Pull Requests могут содержать недоверенный код.

**Шаг 4. Дополнительные параметры**

В разделе `GitHub Enterprise` оставьте поле `Server URL` пустым.

При использовании стандартного GitHub TeamCity определяет адрес сервера по настройкам VCS Root.

**Шаг 5. Сохранение конфигурации**

После заполнения параметров сохраните Build Feature.

В разделе `Build Features` должна появиться запись `Pull Requests`.

Теперь TeamCity настроен на обнаружение Pull Requests, соответствующих указанным условиям.

Само обнаружение Pull Request ещё не означает автоматического запуска сборки. Для этого необходимо дополнительно настроить Build Trigger, который будет запускать проверки при появлении новых изменений.

[← Вернуться к интеграции с GitHub](../README.md#pr-github-integration) | [↑ К содержанию](#toc)

---

<a name="build-triggers"></a>

## 4. Настройка Build Triggers

Для автоматического запуска проверок при изменениях в репозитории используется **VCS Trigger**.

**Шаг 1. Добавление VCS Trigger**

Откройте TeamCity и перейдите в:

`global → 1: PR code reviewer → Triggers`

Нажмите `Add new trigger` и выберите `VCS Trigger`.

**Шаг 2. Настройка Branch Filter**

Оставьте остальные параметры по умолчанию.

В разделе `Branch Filter` укажите:

```text
+:*
```

Этот фильтр разрешает автоматический запуск сборок для всех веток, доступных Build Configuration, включая обнаруженные Pull Requests.

**Шаг 3. Сохранение**

Нажмите `Save` для сохранения настроек.

[← Вернуться к интеграции с GitHub](../README.md#pr-github-integration) | [↑ К содержанию](#toc)

---

<a name="commit-status-publisher"></a>

## 5. Настройка Commit Status Publisher

Для передачи результатов сборок из TeamCity в GitHub используется **Commit Status Publisher**.

Этот компонент публикует статус проверки непосредственно в Pull Request, позволяя GitHub учитывать результат CI при принятии решения о слиянии изменений.

**Шаг 1. Добавление Commit Status Publisher**

Откройте TeamCity и перейдите в:

`global → 1: PR code reviewer → Build Features`

Нажмите `Add build feature` и выберите `Commit Status Publisher`.

**Шаг 2. Настройка публикации статусов**

Укажите следующие параметры:

| Параметр | Значение |
|---|---|
| VCS Root | `cicd-lab-vcs` |
| Publisher | `GitHub` |
| GitHub URL | `https://api.github.com` |
| Authentication Type | `Access Token` |
| Access Token | GitHub Personal Access Token |

Для публикации статусов токен должен иметь соответствующие разрешения GitHub.

При использовании классического Personal Access Token необходимы права `repo:status` и доступ к репозиторию. Для fine-grained токена требуется разрешение `Commit statuses: Read and write`.

**Шаг 3. Проверка подключения**

Нажмите `Test connection`, чтобы проверить доступ к GitHub API.

После успешной проверки сохраните настройки.

Теперь TeamCity будет публиковать результаты сборок в GitHub. Эти статусы будут использоваться в правилах защиты ветки `preprod` для запрета или разрешения слияния Pull Request при проверках.

[← Вернуться к интеграции с GitHub](../README.md#pr-github-integration) | [↑ К содержанию](#toc)

---

<a name="build-steps"></a>

## 6. Настройка Build Steps

В Build Configuration `1: PR code reviewer` используются семь последовательных шагов для сборки приложения, тестирования, анализа качества кода и проверки зависимостей на уязвимости.

Перейдите в `global → 1: PR code reviewer → Build Steps`.

<a name="sonarscanner-begin"></a>

### 6.1. SonarScanner Begin

Первый шаг инициализирует анализ исходного кода в SonarQube. Он определяет, выполняется ли сборка для ветки `preprod` или Pull Request, и передаёт соответствующие параметры в SonarScanner.

**Шаг 1. Добавление Build Step**

Нажмите `Add build step` и укажите:

| Параметр | Значение |
|---|---|
| Runner type | `Command Line` |
| Step name | `SonarScanner Begin` |
| Run | `Custom script` |

**Шаг 2. Настройка параметров SonarQube**

Для подключения к SonarQube используются два параметра TeamCity:

| Параметр | Назначение |
|---|---|
| `env.SONAR_HOST_URL` | Адрес сервера SonarQube |
| `env.SONAR_TOKEN` | Токен для выполнения анализа |

Токен необходимо хранить как параметр типа `Password`, чтобы его значение не отображалось в интерфейсе TeamCity и логах сборки.

**Шаг 3. Добавление скрипта**

В поле `Custom script` добавьте:

```bash
#!/usr/bin/env bash
set -euo pipefail

BRANCH="%teamcity.build.branch%"
SONAR_ARGS=()

if [[ "$BRANCH" == "preprod" || "$BRANCH" == "<default>" ]]; then
    SONAR_ARGS+=(
        "/d:sonar.branch.name=preprod"
    )
else
    SONAR_ARGS+=(
        "/d:sonar.pullrequest.key=%teamcity.pullRequest.number%"
        "/d:sonar.pullrequest.branch=%teamcity.pullRequest.source.branch%"
        "/d:sonar.pullrequest.base=%teamcity.pullRequest.target.branch%"
    )
fi

dotnet-sonarscanner begin \
    /k:"cicd-lab" \
    /n:"cicd-lab" \
    /d:sonar.host.url="%env.SONAR_HOST_URL%" \
    /d:sonar.token="%env.SONAR_TOKEN%" \
    /d:sonar.cs.opencover.reportsPaths="coverage/**/coverage.opencover.xml" \
    /d:sonar.exclusions="**/coverage-report/**,**/trivy-report/**" \
    /d:sonar.qualitygate.wait=true \
    /d:sonar.qualitygate.timeout=300 \
    "${SONAR_ARGS[@]}"
```

**Как работает скрипт**

Скрипт определяет тип сборки с помощью параметра `%teamcity.build.branch%`.

- Для `preprod` анализ выполняется как для обычной ветки SonarQube.
- Для Pull Requests передаются номер PR, исходная и целевая ветки, что позволяет SonarQube анализировать изменения в контексте Pull Request.

Дополнительно настроены импорт результатов покрытия тестами в формате OpenCover, исключение каталогов с генерируемыми отчётами и ожидание результата Quality Gate в течение 300 секунд.

**Шаг 4. Сохранение**

Нажмите `Save`.

SonarScanner инициализирован. После выполнения шагов сборки и тестирования анализ будет завершён отдельным шагом `SonarScanner End`.

[← Вернуться к последовательности Pipeline](../README.md#pr-build-steps) | [↑ К содержанию](#toc)

---

<a name="restore"></a>

### 6.2. Restore

Этот шаг восстанавливает NuGet-зависимости, необходимые для сборки и тестирования .NET-приложения.

**Шаг 1. Добавление Build Step**

Нажмите `Add build step` и выберите `.NET`.

**Шаг 2. Настройка параметров**

| Параметр | Значение |
|---|---|
| Step name | `Restore` |
| Command | `restore` |
| Projects | `CicdLab.sln` |

Остальные параметры оставьте по умолчанию.

**Шаг 3. Сохранение**

Нажмите `Save`.

После выполнения этого шага все необходимые NuGet-пакеты будут восстановлены и доступны для последующей сборки приложения.

[← Вернуться к последовательности Pipeline](../README.md#pr-build-steps) | [↑ К содержанию](#toc)

---

<a name="build"></a>

### 6.3. Build

На этом этапе выполняется компиляция .NET-приложения в конфигурации `Release`.

**Шаг 1. Добавление Build Step**

Нажмите `Add build step` и выберите `.NET`.

**Шаг 2. Настройка параметров**

| Параметр | Значение |
|---|---|
| Step name | `Build` |
| Command | `build` |
| Projects | `CicdLab.sln` |
| Configuration | `Release` |
| Additional arguments | `--no-restore` |

Остальные параметры оставьте по умолчанию.

Аргумент `--no-restore` отключает повторное восстановление NuGet-зависимостей, поскольку они уже были восстановлены на предыдущем шаге `Restore`.

**Шаг 3. Сохранение**

Нажмите `Save`.

После успешного выполнения приложение будет скомпилировано и готово к запуску автоматизированных тестов.

[← Вернуться к последовательности Pipeline](../README.md#pr-build-steps) | [↑ К содержанию](#toc)

---

<a name="test"></a>

### 6.4. Test

На этом этапе выполняются автоматизированные тесты .NET-приложения и собираются данные о покрытии кода.

Результаты покрытия будут использоваться SonarQube для анализа качества кода и проверки Quality Gate.

**Шаг 1. Настройка Coverlet**

В корне репозитория создайте файл `coverlet.runsettings` со следующим содержимым:

```xml
<?xml version="1.0" encoding="utf-8"?>
<RunSettings>
    <DataCollectionRunSettings>
        <DataCollectors>
            <DataCollector friendlyName="XPlat Code Coverage">
                <Configuration>
                    <Format>opencover</Format>
                    <Exclude>[CicdLab.Api]Microsoft.AspNetCore.OpenApi.Generated*,[CicdLab.Api]System.Runtime.CompilerServices.*</Exclude>
                </Configuration>
            </DataCollector>
        </DataCollectors>
    </DataCollectionRunSettings>
</RunSettings>
```

Данный файл определяет параметры сбора данных о покрытии кода и формат выходного отчёта.

Хранение конфигурации в отдельном файле позволяет:

- Использовать одинаковые настройки при локальном запуске тестов и в CI/CD.
- Хранить конфигурацию тестового покрытия в системе контроля версий.
- Избежать проблем с экранированием аргументов командной строки.
- Обеспечить совместимость с .NET 9 и .NET 10 при использовании VSTest.

**Шаг 2. Добавление Build Step**

Нажмите `Add build step` и выберите `.NET`.

**Шаг 3. Настройка параметров**

| Параметр | Значение |
|---|---|
| Step name | `Test` |
| Command | `test` |
| Projects | `CicdLab.sln` |
| Configuration | `Release` |
| Additional arguments | `--no-build --settings coverlet.runsettings --results-directory coverage` |

Остальные параметры оставьте по умолчанию.

**Что такое XPlat Code Coverage?**

`XPlat Code Coverage` — это кроссплатформенный сборщик данных о покрытии кода тестами для .NET, предоставляемый пакетом `coverlet.collector`.

Он отслеживает, какие участки исходного кода были выполнены во время тестирования, и позволяет определить, какая часть приложения проверяется автоматизированными тестами.

Здесь он используется для формирования отчёта в формате **OpenCover**, который поддерживается SonarQube и ReportGenerator.

Параметры сборщика и формат отчёта определяются в файле `coverlet.runsettings`, поэтому передавать их через аргумент `--collect` больше не требуется.

**Дополнительные аргументы:**

- `--no-build` — отключает повторную компиляцию приложения, поскольку сборка уже выполнена на предыдущем шаге.
- `--settings coverlet.runsettings` — указывает файл конфигурации тестирования и сбора данных о покрытии кода.
- `--results-directory coverage` — указывает каталог для сохранения результатов тестирования и файлов покрытия.

**Шаг 4. Сохранение**

Нажмите `Save`.

После выполнения шага TeamCity получит результаты автоматизированных тестов, а файлы `coverage.opencover.xml` будут сохранены в подкаталогах каталога `coverage`.

В дальнейшем эти данные будут переданы в SonarQube для анализа покрытия кода и использованы при формировании HTML-отчёта.

[← Вернуться к последовательности Pipeline](../README.md#pr-build-steps) | [↑ К содержанию](#toc)

---

<a name="sonarscanner-end"></a>

### 6.5. SonarScanner End

Этот шаг завершает анализ исходного кода в SonarQube, начатый на этапе `SonarScanner Begin`.

После выполнения сборки и тестирования SonarScanner собирает результаты анализа, включая данные о покрытии кода, и отправляет их на сервер SonarQube.

**Шаг 1. Добавление Build Step**

Нажмите `Add build step` и выберите `Command Line`.

**Шаг 2. Настройка параметров**

| Параметр | Значение |
|---|---|
| Step name | `SonarScanner End` |
| Run | `Custom script` |

**Шаг 3. Добавление скрипта**

В поле `Custom script` добавьте:

```bash
#!/usr/bin/env bash
set -euo pipefail

dotnet-sonarscanner end \
    /d:sonar.token="%env.SONAR_TOKEN%"
```

Параметр `env.SONAR_TOKEN` используется для аутентификации при отправке результатов анализа в SonarQube.

**Проверка Quality Gate**

После завершения анализа SonarQube проверяет код на соответствие настроенным критериям качества — **Quality Gate**.

В этом тестовом проекте один из критериев — покрытие нового кода тестами не менее **80%**.

В шаге `SonarScanner Begin` уже указаны параметры:

- `sonar.qualitygate.wait=true` — ожидание результата Quality Gate.
- `sonar.qualitygate.timeout=300` — максимальное время ожидания составляет 300 секунд.

Если Quality Gate не пройден, анализ завершится ошибкой, и TeamCity отметит сборку как неуспешную.

**Шаг 4. Сохранение**

Нажмите `Save`.

После успешного выполнения шага результаты анализа будут доступны в интерфейсе SonarQube, включая обнаруженные проблемы качества кода и показатели покрытия тестами.

[← Вернуться к последовательности Pipeline](../README.md#pr-build-steps) | [↑ К содержанию](#toc)

---

<a name="coverage-report"></a>

### 6.6. Coverage Report

На этом этапе формируется HTML-отчёт о покрытии исходного кода автоматизированными тестами.

Для генерации отчёта используется **ReportGenerator** — инструмент, который преобразует результаты покрытия из формата OpenCover в удобные для просмотра отчёты.

**Шаг 1. Добавление Build Step**

Перейдите в `global → 1: PR code reviewer → Build Steps`.

Нажмите `Add build step` и выберите `Command Line`.

**Шаг 2. Настройка параметров**

| Параметр | Значение |
|---|---|
| Step name | `Coverage Report` |
| Run | `Custom script` |
| Execute step | `Even if some of the previous steps failed` |

Последний параметр позволяет попытаться сформировать отчёт даже при ошибке предыдущих шагов, если файлы покрытия были созданы.

**Шаг 3. Добавление скрипта**

В поле `Custom script` добавьте:

```bash
#!/usr/bin/env bash
set -euo pipefail

/usr/local/bin/reportgenerator \
    "-reports:coverage/**/coverage.opencover.xml" \
    "-targetdir:coverage-report" \
    "-reporttypes:Html;HtmlSummary;TextSummary"

echo "Coverage report generated successfully"
ls -lah coverage-report/
```

Основные параметры ReportGenerator:

| Параметр | Назначение |
|---|---|
| `-reports` | Путь к файлам покрытия, сформированным на этапе `Test` |
| `-targetdir` | Каталог для сохранения готовых отчётов |
| `-reporttypes` | Форматы создаваемых отчётов: `Html`, `HtmlSummary`, `TextSummary` |

ReportGenerator формирует отчёт, в котором можно посмотреть общий процент покрытия, показатели отдельных классов и методов, а также строки кода, выполненные или не выполненные во время тестирования.

Нажмите `Save`.

**Шаг 4. Настройка публикации отчётов в TeamCity**

Чтобы результаты покрытия сохранялись после завершения сборки и были доступны через интерфейс TeamCity, необходимо настроить публикацию артефактов.

1. Перейдите в `global → 1: PR code reviewer → General Settings`.
2. Найдите поле `Artifact paths`.
3. Добавьте следующие правила:

```text
coverage-report/** => coverage-report
coverage/**/coverage.opencover.xml => coverage-raw
```

Назначение правил:

| Правило | Назначение |
|---|---|
| `coverage-report/** => coverage-report` | Публикует готовые HTML-отчёты ReportGenerator |
| `coverage/**/coverage.opencover.xml => coverage-raw` | Публикует исходные файлы покрытия OpenCover, сформированные на этапе тестирования |

Сохранение исходных файлов OpenCover позволяет использовать их для дополнительного анализа без повторного запуска тестов.

4. В параметре `Publish artifacts` выберите `Even if build fails`, чтобы TeamCity публиковал доступные отчёты даже при неуспешной сборке.
5. Сохраните изменения.

**Шаг 5. Просмотр результатов**

После выполнения Pipeline откройте нужную сборку в TeamCity и перейдите на вкладку `Artifacts`.

Там будут доступны два каталога:

- `coverage-report` — готовые отчёты ReportGenerator, включая `index.html`.
- `coverage-raw` — исходные XML-файлы покрытия в формате OpenCover.

HTML-отчёт можно скачать и открыть в браузере, а XML-файлы использовать для дальнейшего анализа покрытия кода.

[← Вернуться к последовательности Pipeline](../README.md#pr-build-steps) | [↑ К содержанию](#toc)

---

<a name="trivy-dependency-scan"></a>

### 6.7. Trivy Dependency Scan

На этом этапе выполняется проверка зависимостей проекта на известные уязвимости с помощью **Trivy**.

Trivy — инструмент безопасности с открытым исходным кодом, который позволяет обнаруживать уязвимости в зависимостях приложений, контейнерных образах и других компонентах программного обеспечения.

В этом Pipeline используется режим `fs` (filesystem), который анализирует файлы проекта и зависимости, определяемые по поддерживаемым манифестам и lock-файлам.

Проверка выполняется в три этапа:

1. Формирование JSON-отчёта для машинной обработки.
2. Формирование HTML-отчёта для удобного просмотра.
3. Проверка критичности уязвимостей с блокировкой сборки.

**Шаг 1. Добавление Build Step**

Перейдите в `global → 1: PR code reviewer → Build Steps`.

Нажмите `Add build step` и выберите `Command Line`.

**Шаг 2. Настройка параметров**

| Параметр | Значение |
|---|---|
| Step name | `Trivy - Dependency Scan` |
| Run | `Custom script` |
| Working directory | `%teamcity.build.checkoutDir%` |

Рабочий каталог указывает на исходный код проекта, загруженный TeamCity из GitHub.

**Шаг 3. Добавление скрипта**

В поле `Custom script` добавьте:

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "=================================="
echo "Trivy Dependency Vulnerability Scan"
echo "=================================="

mkdir -p trivy-report

# JSON-отчёт для машинной обработки
trivy --config "" fs \
  --scanners vuln \
  --severity HIGH,CRITICAL \
  --format json \
  --output trivy-report/report.json \
  .

# HTML-отчёт для просмотра результатов
trivy --config "" fs \
  --scanners vuln \
  --severity LOW,MEDIUM,HIGH,CRITICAL \
  --skip-dirs "tests/*/bin" \
  --format template \
  --template "@/usr/local/share/trivy/templates/html.tpl" \
  --output trivy-report/index.html \
  .

# Блокировка сборки при HIGH и CRITICAL
trivy --config "" fs \
  --scanners vuln \
  --severity HIGH,CRITICAL \
  --exit-code 1 \
  --format table \
  .
```

**Как работает скрипт**

**1. Формирование JSON-отчёта**

Trivy сканирует проект на уязвимости уровней `HIGH` и `CRITICAL` и сохраняет результаты в `trivy-report/report.json`.

JSON-формат удобен для автоматизированной обработки результатов другими инструментами.

**2. Формирование HTML-отчёта**

Второй запуск Trivy создаёт HTML-отчёт `trivy-report/index.html`.

В отличие от JSON-отчёта, здесь включены все четыре уровня серьёзности уязвимостей:

| Уровень | Значение |
|---|---|
| `LOW` | Низкий |
| `MEDIUM` | Средний |
| `HIGH` | Высокий |
| `CRITICAL` | Критический |

Для генерации HTML используется шаблон `/usr/local/share/trivy/templates/html.tpl`, который должен быть заранее доступен на Build Agent.

**3. Блокировка сборки**

Последняя команда повторно проверяет зависимости на уязвимости уровней `HIGH` и `CRITICAL`.

Ключевой параметр:

```text
--exit-code 1
```

Если Trivy обнаруживает уязвимости указанных уровней, команда возвращает код завершения `1`, и TeamCity отмечает Build Step как неуспешный.

Таким образом, уязвимости `LOW` и `MEDIUM` отображаются в HTML-отчёте, но не блокируют Pipeline, а `HIGH` и `CRITICAL` блокируют сборку.

Параметр `--config ""` используется для отключения загрузки конфигурации Trivy из стандартного файла конфигурации, чтобы проверки выполнялись с явно указанными аргументами.

**Шаг 4. Сохранение**

Нажмите `Save`.

**Шаг 5. Настройка публикации Trivy-отчётов**

Чтобы отчёты сохранялись после завершения сборки, необходимо настроить их публикацию в TeamCity.

1. Перейдите в `global → 1: PR code reviewer → General Settings`.
2. Найдите поле `Artifact paths`.
3. Добавьте правило:

```text
trivy-report/** => trivy-report
```

Это правило публикует JSON- и HTML-отчёты из каталога `trivy-report` в артефактах сборки.

4. В параметре `Publish artifacts` выберите `Even if build fails`.
5. Сохраните изменения.

Это особенно важно для Trivy: если обнаружены уязвимости `HIGH` или `CRITICAL`, сборка завершится ошибкой, но сформированные отчёты останутся доступны для анализа.

**Шаг 6. Просмотр результатов**

После выполнения Pipeline откройте нужную сборку в TeamCity и перейдите на вкладку `Artifacts`.

В каталоге `trivy-report` будут доступны:

| Файл | Назначение |
|---|---|
| `report.json` | JSON-отчёт с уязвимостями `HIGH` и `CRITICAL` |
| `index.html` | HTML-отчёт с уязвимостями всех уровней |

HTML-отчёт можно скачать и открыть в браузере для подробного изучения обнаруженных уязвимостей.

Таким образом, Trivy выполняет роль **Security Gate**: Pipeline не проходит проверку при обнаружении уязвимостей высокой или критической серьёзности.

[← Вернуться к последовательности Pipeline](../README.md#pr-build-steps) | [↑ К содержанию](#toc)

---

<a name="build-report-tabs"></a>

## 7. Настройка Build Report Tabs

TeamCity позволяет отображать HTML-отчёты непосредственно в интерфейсе сборки с помощью **Build Report Tabs**.

В нашем Pipeline используются две дополнительные вкладки:

- **Coverage Report** — отчёт о покрытии кода автоматизированными тестами, сформированный ReportGenerator.
- **Trivy Report** — отчёт об обнаруженных уязвимостях зависимостей, сформированный Trivy.

Для отображения отчётов необходимо предварительно настроить их публикацию через `Artifact paths`, как описано в разделах 3.8.6 и 3.8.7.

**Шаг 1. Открытие настроек Report Tabs**

1. Перейдите в `Administration → Projects → global`.
2. Откройте раздел `Report Tabs`.
3. Нажмите `Create new build report tab`.

**Шаг 2. Создание вкладки Coverage Report**

Укажите следующие параметры:

| Параметр | Значение |
|---|---|
| Tab title | `Coverage Report` |
| Start page | `coverage-report/index.html` |

Нажмите `Save`.

Эта вкладка будет использовать HTML-отчёт, сформированный на этапе `Coverage Report`.

**Шаг 3. Создание вкладки Trivy Report**

Аналогичным образом создайте вторую вкладку:

| Параметр | Значение |
|---|---|
| Tab title | `Trivy Report` |
| Start page | `trivy-report/index.html` |

Нажмите `Save`.

Эта вкладка будет отображать HTML-отчёт, сформированный на этапе `Trivy - Dependency Scan`.

**Шаг 4. Проверка отображения отчётов**

После выполнения Pipeline:

1. Перейдите в `global → 1: PR code reviewer`.
2. Откройте завершённую сборку.
3. Убедитесь, что появились вкладки `Coverage Report` и `Trivy Report`.
4. Откройте каждую вкладку и проверьте отображение HTML-отчёта.

**Важно:** Build Report Tabs не генерируют отчёты самостоятельно. Они отображают HTML-файлы, которые были созданы соответствующими Build Steps и опубликованы как артефакты TeamCity.

Если HTML-файл не был сформирован или опубликован, содержимое соответствующей вкладки будет недоступно.

[← Вернуться к отчётам и результатам проверок](../README.md#pr-reports) | [↑ К содержанию](#toc)

---

<a name="pipeline-verification"></a>

## 8. Проверка работы PR code reviewer

После завершения настройки первого Pipeline необходимо проверить полный цикл автоматизированной проверки изменений, начиная с создания Pull Request и заканчивая публикацией результатов в GitHub.

**Шаг 1. Создание Pull Request**

Создайте ветку `feature/*` на основе `preprod`, внесите изменения в исходный код приложения и отправьте их в GitHub.

Создайте Pull Request со следующими параметрами:

| Параметр | Значение |
|---|---|
| Base branch | `preprod` |
| Compare branch | `feature/*` |

После создания Pull Request TeamCity должен автоматически запустить Build Configuration `1: PR code reviewer`.

**Шаг 2. Проверка выполнения Pipeline в TeamCity**

Перейдите в `global → 1: PR code reviewer` и откройте запущенную сборку.

Убедитесь, что все семь Build Steps выполнены успешно:

| Build Step | Ожидаемый результат |
|---|---|
| SonarScanner Begin | Анализ SonarQube инициализирован |
| Restore | NuGet-зависимости восстановлены |
| Build | Приложение успешно скомпилировано |
| Test | Тесты пройдены, данные покрытия собраны |
| SonarScanner End | Анализ завершён, Quality Gate пройден |
| Coverage Report | Отчёт о покрытии сформирован |
| Trivy - Dependency Scan | Уязвимости HIGH и CRITICAL не обнаружены |

**Шаг 3. Проверка результатов анализа в SonarQube**

Откройте проект `cicd-lab` в SonarQube и выберите соответствующий Pull Request.

Убедитесь, что:

- Pull Request отображается в SonarQube.
- Результаты анализа исходного кода доступны.
- Данные о покрытии нового кода импортированы.
- Quality Gate имеет статус `Passed`.

**Шаг 4. Проверка отчётов в TeamCity**

Откройте завершённую сборку и проверьте содержимое следующих вкладок:

| Вкладка | Содержимое |
|---|---|
| Tests | Результаты автоматизированных тестов |
| Coverage Report | HTML-отчёт о покрытии кода |
| Trivy Report | HTML-отчёт об уязвимостях зависимостей |
| Artifacts | Опубликованные файлы отчётов |

**Шаг 5. Проверка статуса Pull Request в GitHub**

Вернитесь к созданному Pull Request в GitHub.

Убедитесь, что TeamCity опубликовал статус проверки `1: PR code reviewer (global)` и GitHub учитывает его при определении возможности слияния изменений в ветку `preprod`.

**Шаг 6. Проверка блокировки слияния**

Для проверки корректности работы защитных механизмов необходимо протестировать не только успешный, но и неуспешный сценарий выполнения Pipeline.

| Сценарий | Ожидаемый результат |
|---|---|
| Ошибка компиляции | Сборка заблокирована |
| Неуспешный тест | Сборка заблокирована |
| Quality Gate не пройден | Сборка заблокирована |
| Обнаружена уязвимость HIGH или CRITICAL | Сборка заблокирована |
| Все проверки пройдены | Обязательная проверка GitHub пройдена |

При неуспешном выполнении Pipeline TeamCity публикует соответствующий статус в GitHub, а настроенные правила защиты ветки `preprod` запрещают слияние Pull Request.

После устранения обнаруженных проблем и отправки исправлений в GitHub TeamCity автоматически запускает повторную проверку.

**Результат**

Первый Pipeline полностью настроен и обеспечивает автоматизированный контроль качества и безопасности исходного кода до его попадания в ветку `preprod`.

Слияние изменений становится возможным только после успешного прохождения обязательных проверок и выполнения остальных настроенных требований GitHub.


[← Вернуться к отчётам и результатам проверок](../README.md#pr-reports) | [↑ К содержанию](#toc)

---

[← Вернуться к основной документации](../README.md#pr-code-reviewer)
