# CI/CD Pipeline с TeamCity, GitHub, SonarQube, Trivy, Docker и Cosign

## О проекте

<p align="center">
  <img src="docs/images/devsecops-pipeline.png" alt="DevSecOps Pipeline" width="100%">
</p>

Этот проект представляет собой практический пример построения автоматизированного CI/CD-процесса для .NET-приложения с использованием инструментов контроля качества кода, анализа безопасности и цифровой подписи Docker-образов.

Основная цель — организовать процесс разработки, при котором каждое изменение исходного кода проходит обязательные проверки перед объединением с защищёнными ветками, а Docker-образы собираются и публикуются только после успешного завершения проверок.

Для этого используются следующие инструменты:

- **GitHub** — хранение исходного кода, управление ветками и Pull Requests.
- **TeamCity** — автоматизация сборки, тестирования и публикации Docker-образов.
- **SonarQube** — статический анализ исходного кода и контроль Quality Gate.
- **Trivy** — сканирование исходного проекта и Docker-образов на уязвимости.
- **Docker** — сборка контейнерных образов приложения.
- **Docker Hub** — хранение и распространение Docker-образов.
- **CycloneDX SBOM** — формирование перечня компонентов и зависимостей Docker-образа.
- **Cosign** — цифровая подпись Docker-образов и проверка их целостности.

Процесс разделён на два Pipeline:

1. **PR Code Reviewer** — выполняет сборку и тестирование приложения, анализирует покрытие кода, проверяет качество через SonarQube и сканирует проект с помощью Trivy.
2. **Building & Deployment** — собирает Docker-образ, проверяет его безопасность, формирует SBOM, публикует образ в Docker Hub и подписывает его с помощью Cosign.

Второй Pipeline запускается автоматически после успешного завершения первого для ветки `preprod`.

Представленную конфигурацию можно использовать как основу для построения CI/CD в других проектах, адаптируя её под используемые технологии и требования безопасности.

---

## 1. Используемые инструменты и зависимости

В этом разделе перечислены инструменты, необходимые для работы CI/CD, и их назначение.

### 1.1. TeamCity Server

| Инструмент | Назначение |
|---|---|
| TeamCity | Управление Pipeline, настройка Build Configurations, запуск и контроль сборок |
| OpenJDK | Среда выполнения Java для TeamCity |
| PostgreSQL | Хранение конфигурации, истории сборок и других данных TeamCity |
| PostgreSQL JDBC Driver | Подключение TeamCity к PostgreSQL |

### 1.2. TeamCity Build Agent

На Build Agent выполняются основные операции CI/CD: компиляция приложения, тестирование, анализ кода, сборка и публикация Docker-образов.

| Инструмент | Назначение |
|---|---|
| OpenJDK | Работа TeamCity Build Agent |
| Git | Получение исходного кода из GitHub |
| .NET SDK | Сборка и тестирование .NET-приложения |
| SonarScanner for .NET | Анализ исходного кода и передача результатов в SonarQube |
| ReportGenerator | Формирование HTML-отчётов о покрытии кода тестами |
| Trivy | Проверка файлов проекта и Docker-образов на уязвимости |
| Docker Engine | Сборка и локальная работа с контейнерными образами |
| Docker Buildx | Расширенные возможности сборки Docker-образов |
| Cosign | Цифровая подпись Docker-образов и проверка подписей |
| Python 3 | Обработка JSON-отчётов и SBOM в скриптах Pipeline |

### 1.3. SonarQube Server

| Инструмент | Назначение |
|---|---|
| SonarQube | Статический анализ исходного кода и контроль Quality Gate |
| PostgreSQL | Хранение результатов анализа и данных SonarQube |
| Java Runtime | Работа компонентов SonarQube, использующих Java |

### 1.4. Внешние сервисы

| Сервис | Назначение |
|---|---|
| GitHub | Хранение исходного кода, работа с Pull Requests и защита веток |
| Docker Hub | Хранение Docker-образов и связанных с ними цифровых подписей |
| Sigstore | Инфраструктура и форматы цифровых подписей, используемые Cosign |

### 1.5. Зависимости .NET-проекта

| Пакет | Назначение |
|---|---|
| xUnit | Написание и выполнение автоматизированных тестов |
| Microsoft.AspNetCore.Mvc.Testing | Интеграционное тестирование ASP.NET Core API |
| coverlet.collector | Сбор данных о покрытии кода тестами |
| Microsoft.AspNetCore.OpenApi | Поддержка OpenAPI в приложении |

Конкретные версии NuGet-пакетов определяются файлами `.csproj` проекта.

---

## 2. Настройка GitHub

### 2.1. Организация репозитория и веток

Для хранения исходного кода и управления изменениями используется GitHub.

Репозиторий проекта: [mdv-devops/cicd-lab](https://github.com/mdv-devops/cicd-lab).

В репозитории используются три типа веток:

| Ветка | Назначение |
|---|---|
| `main` | Основная защищённая ветка проекта. Изменения в неё переносятся через Pull Request из `preprod`. |
| `preprod` | Защищённая ветка, в которой объединяются и проверяются изменения разработчиков перед переносом в `main`. |
| `feature/*` | Рабочие ветки разработчиков, предназначенные для новых функций, исправлений и других изменений. |

Ветка `main` установлена в GitHub как ветка по умолчанию.

### 2.2. Порядок внесения изменений

**Шаг 1. Создание рабочей ветки**

Разработчик создаёт новую ветку от `preprod`, например `feature/add-endpoint`.

Все изменения выполняются в этой ветке, без прямого изменения `preprod` или `main`.

**Шаг 2. Создание Pull Request в `preprod`**

После завершения работы разработчик отправляет изменения в GitHub и создаёт Pull Request из своей рабочей ветки в `preprod`.

Для объединения изменений необходимо:

- Успешно пройти настроенные автоматические проверки.
- Получить обязательное одобрение Pull Request по результатам проверки (Teamcity Approve).

**Шаг 3. Объединение изменений в `preprod`**

После выполнения всех требований Pull Request можно объединить с `preprod`.

- Получить обязательное одобрение Pull Request от teamleader (Manual Approve (Не возможно без Teamcity Approve))

На этом этапе изменения становятся частью общей интеграционной ветки.

**Шаг 4. Создание Pull Request в `main`**

После проверки изменений в `preprod` создаётся отдельный Pull Request из `preprod` в `main`.

Объединение выполняется с соблюдением правил защиты основной ветки.

Прямое внесение изменений в `main` и `preprod` запрещено.

### 2.3. Схема работы с ветками

```text
feature/add-endpoint ── PR + Approve ──┐
                                      │
feature/fix-bug ─────── PR + Approve ──┤
                                      ▼
                               preprod (protected)
                                      │
                                      │ Pull Request
                                      ▼
                                 main (protected)
```

Такая схема позволяет разделить повседневную разработку и основную ветку проекта.

Изменения сначала проходят проверку и согласование в `preprod`, а затем переносятся в `main` через отдельный Pull Request.

### 2.4. Настройка защиты ветки `preprod`

Ветка `preprod` используется для объединения изменений разработчиков перед их переносом в `main`.

Для защиты ветки применяется GitHub Ruleset, который запрещает прямое внесение изменений, требует создания Pull Request и успешного прохождения автоматических проверок.

**Шаг 1. Создание Ruleset**

Откройте репозиторий и перейдите в:

`Settings → Rules → Rulesets → New ruleset → New branch ruleset`

Укажите следующие параметры:

| Параметр | Значение |
|---|---|
| Ruleset Name | `preprod-protection` |
| Enforcement status | `Active` |
| Bypass list | Пустой |
| Target branches | `preprod` |

Пустой `Bypass list` означает, что пользователям и приложениям не предоставлены исключения из правил защиты.

**Шаг 2. Настройка основных правил**

В разделе `Branch rules` включите:

| Настройка | Назначение |
|---|---|
| Restrict deletions | Запрещает удаление ветки |
| Require a pull request before merging | Требует Pull Request для внесения изменений |
| Require status checks to pass | Требует успешных автоматических проверок |
| Block force pushes | Запрещает принудительную перезапись истории |

Остальные правила оставьте выключенными.

**Шаг 3. Настройка обязательного Pull Request**

Раскройте:

`Require a pull request before merging → Show additional settings`

Укажите следующие значения:

| Параметр | Значение |
|---|---|
| Required approvals | `1` |
| Dismiss stale pull request approvals when new commits are pushed | Включено |
| Require review from specific teams | Выключено |
| Require review from Code Owners | Выключено |
| Require approval of the most recent reviewable push | Выключено |
| Require conversation resolution before merging | Включено |
| Require an additional approval for unattributed Copilot pull requests | Включено |
| Allowed merge methods | `Merge` |

**Required approvals: 1**

Для объединения Pull Request требуется минимум одно одобрение от другого участника, имеющего право проверять изменения.

**Dismiss stale pull request approvals**

Если после получения Approve разработчик добавит новые коммиты, предыдущие одобрения будут сброшены. Pull Request потребуется проверить повторно.

**Require conversation resolution before merging**

Все обсуждения изменений в коде должны быть завершены перед объединением Pull Request.

**Allowed merge methods: Merge**

При объединении Pull Request все его коммиты видны в целевой ветке.

**Шаг 4. Настройка обязательных проверок TeamCity**

Раскройте:

`Require status checks to pass → Show additional settings`

Установите следующие параметры:

| Параметр | Значение |
|---|---|
| Require branches to be up to date before merging | Выключено |
| Do not require status checks on creation | Выключено |
| Required status checks | `1: PR code reviewer (global)` |
| Source | `Any source` |

Проверка `1: PR code reviewer (global)` используется GitHub для контроля результата CI-сборки.

Если проверка не прошла или не завершилась, GitHub блокирует объединение Pull Request.

Параметр `Require branches to be up to date before merging` выключен. Поэтому GitHub не требует предварительного обновления рабочей ветки до последнего состояния `preprod`, если обязательная проверка уже прошла успешно.

**Шаг 5. Сохранение правил**

Нажмите `Save changes`.

После применения правил teamleader вручную сможет объединить Pull Request в `preprod` только после выполнения обязательных условий: успешной проверки CI и получения Approve от Teamcity.

Прямые изменения, удаление ветки и принудительная перезапись истории будут запрещены.

### 2.5. Настройка защиты ветки `main`

*Настройка защиты ветки main будет описана после реализации процесса развёртывания приложения в Kubernetes, выполнения проверок после развёртывания и определения механизма автоматического создания Pull Request из preprod в main.*

## 3. Настройка TeamCity

TeamCity используется для автоматизации проверки исходного кода, запуска тестов, анализа безопасности, сборки и публикации Docker-образов.

### 3.1. Создание проекта

**Шаг 1. Создание нового проекта**

Откройте TeamCity и перейдите в раздел:

`Administration → Projects`

Нажмите `Create project` и выберите создание проекта вручную.

Укажите следующие параметры:

| Параметр | Значение |
|---|---|
| Name | `global` |
| Project ID | `Global` |
| Description | Оставить пустым |

Сохраните проект.

**Шаг 2. Проверка общих настроек**

Откройте:

`Administration → Projects → global → General`

Убедитесь, что проект создан с указанными параметрами.

Дополнительные шаблоны настроек (`Default template` и `Enforced settings template`) в нашем примере не используются.

В дальнейшем внутри проекта будут созданы две Build Configurations:

1. **PR code reviewer** — сборка приложения, тестирование, анализ качества кода и поиск уязвимостей.
2. **Building & Deployment** — сборка Docker-образа, сканирование, формирование SBOM, публикация и цифровая подпись.

Каждая конфигурация будет настроена отдельно.

### 3.2. Подключение GitHub через VCS Root

Для получения исходного кода из GitHub необходимо настроить **VCS Root** — подключение, через которое TeamCity получает доступ к Git-репозиторию и отслеживает изменения.

VCS Root создаётся на уровне проекта и может использоваться несколькими Build Configurations.

**Шаг 1. Создание VCS Root**

Откройте TeamCity и перейдите в настройки проекта:

`Administration → Projects → global → VCS Roots`

Нажмите `Create VCS Root` и выберите тип системы контроля версий `Git`.

В разделе `General Settings` укажите следующие параметры:

| Параметр | Значение |
|---|---|
| VCS root name | `cicd-lab-vcs` |
| VCS root ID | `Global_CicdLabVcs` |
| Fetch URL | `https://github.com/mdv-devops/cicd-lab.git` |
| Default branch | `refs/heads/preprod` |
| Branch specification | Оставить пустым |

**Fetch URL** — адрес Git-репозитория, из которого TeamCity будет получать исходный код.

**Default branch** — ветка, используемая TeamCity по умолчанию для отслеживания изменений и выполнения сборок.

**Branch specification** — позволяет дополнительно указать ветки, которые TeamCity должен отслеживать. В нашем примере поле оставляем пустым. Обнаружение Pull Requests настроим отдельно.

**Шаг 2. Настройка аутентификации**

В разделе `Authentication Settings` выберите:

`Authentication method → Password / personal access token`

Заполните параметры:

| Параметр | Значение |
|---|---|
| Authentication method | `Password / personal access token` |
| Username | `Teamcity` |
| Password / access token | GitHub Personal Access Token |

Для подключения используется GitHub Personal Access Token (PAT).

Токен позволяет TeamCity обращаться к GitHub по HTTPS и получать исходный код репозитория.

Для чтения репозитория достаточно соответствующих разрешений на доступ к его содержимому. Дополнительные права следует предоставлять только при необходимости.

**Важно:** токен не должен храниться в исходном коде проекта или публиковаться в документации. Используйте защищённое поле TeamCity для хранения учётных данных.

**Шаг 3. Сохранение и проверка подключения**

После заполнения параметров проверьте доступность репозитория с помощью `Test connection`.

При успешном подключении сохраните VCS Root.

В списке VCS Roots проекта должен появиться:

`cicd-lab-vcs`

Созданный VCS Root будет использоваться для получения исходного кода в Build Configurations.



# === 1: PR code reviewer ===

### 3.3. Создание Build Configuration `PR code reviewer`

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

### 3.4. Подключение VCS Root к Build Configuration

После создания Build Configuration необходимо подключить к ней ранее настроенный VCS Root. Это позволит TeamCity получать исходный код приложения из GitHub.

**Шаг 1. Подключение VCS Root**

Откройте TeamCity и перейдите в:

`global → 1: PR code reviewer → Version Control`

Нажмите `Attach VCS root`.

В появившемся окне выберите ранее созданный VCS Root:

`cicd-lab-vcs`

Подтвердите подключение.

### 3.5. Настройка Pull Requests Build Feature

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

### 3.6. Настройка Build Triggers

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

### 3.7. Настройка Commit Status Publisher

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

### 3.8. Настройка Build Steps

В Build Configuration `1: PR code reviewer` используются семь последовательных шагов для сборки приложения, тестирования, анализа качества кода и проверки зависимостей на уязвимости.

Перейдите в `global → 1: PR code reviewer → Build Steps`.

#### 3.8.1. SonarScanner Begin

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

#### 3.8.2. Restore

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

#### 3.8.3. Build

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

#### 3.8.4. Test

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

#### 3.8.5. SonarScanner End

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

#### 3.8.6. Coverage Report

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

#### 3.8.7. Trivy Dependency Scan

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

<text weight="medium">1. Формирование JSON-отчёта</text>

Trivy сканирует проект на уязвимости уровней `HIGH` и `CRITICAL` и сохраняет результаты в `trivy-report/report.json`.

JSON-формат удобен для автоматизированной обработки результатов другими инструментами.

<text weight="medium">2. Формирование HTML-отчёта</text>

Второй запуск Trivy создаёт HTML-отчёт `trivy-report/index.html`.

В отличие от JSON-отчёта, здесь включены все четыре уровня серьёзности уязвимостей:

| Уровень | Значение |
|---|---|
| `LOW` | Низкий |
| `MEDIUM` | Средний |
| `HIGH` | Высокий |
| `CRITICAL` | Критический |

Для генерации HTML используется шаблон `/usr/local/share/trivy/templates/html.tpl`, который должен быть заранее доступен на Build Agent.

<text weight="medium">3. Блокировка сборки</text>

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

### 3.9. Настройка Build Report Tabs

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

### 3.10. Проверка работы PR code reviewer

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



# === 2: Building & Deployment ===

## 4. Настройка Building & Deployment

Pipeline `2: Building & Deployment` предназначен для автоматизации сборки контейнерного образа приложения, проверки его безопасности, формирования SBOM, публикации в контейнерном реестре и цифрового подписания.

Pipeline автоматически запускается после успешного слияния Pull Request в ветку `preprod` и прохождения проверок обновлённой ветки.

### 4.1. Создание Build Configuration

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

### 4.2. Подключение VCS Root

Для Pipeline `2: Building & Deployment` создадим отдельный VCS Root, который будет отслеживать изменения только в ветке `preprod`.

**Шаг 1. Создание VCS Root**

Перейдите в `Administration → Projects → global → VCS Roots`.

Нажмите `Create VCS root` и выберите тип `Git`.

**Шаг 2. Настройка параметров**

| Параметр | Значение |
|---|---|
| VCS root name | `Building & Development vcs` |
| VCS root ID | `Global_BuildingDevelopmentVcs` |
| Fetch URL | `https://github.com/mdv-devops/cicd-lab.git` |
| Default branch | `refs/heads/preprod` |
| Branch specification | Оставить пустым |
| Authentication method | `Password / personal access token` |
| Username | `Teamcity` |
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

### 4.3. Настройка подключения к Docker Hub

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

### 4.4. Настройка Build Trigger

Для автоматического запуска Pipeline `2: Building & Deployment` используется **Finish Build Trigger**.

Pipeline должен запускаться только после слияния Pull Request в ветку `preprod` и успешного завершения проверки обновлённой ветки в `1: PR code reviewer`.

### 4.4. Настройка Snapshot Dependency

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

### 4.5. Настройка Build Trigger

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

### 4.6. Настройка Build Steps

Перейдите в `global → 2: Building & Deployment → Build Steps`.

#### 4.6.1. Build

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

#### 4.6.2. Trivy Image Scan

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

#### 4.6.3. Generate SBOM
---
> **Статус: будет доработан.**
>
> На текущем этапе реализовано формирование SBOM и его сохранение в артефактах TeamCity.
>
> В дальнейшем планируется интеграция с централизованной системой хранения и анализа SBOM для отслеживания программных компонентов, мониторинга вновь обнаруженных уязвимостей и управления рисками цепочки поставок программного обеспечения (Software Supply Chain Security).
---
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

#### 4.6.4. Push

На этом этапе выполняется публикация контейнерного образа в Docker Hub после успешного прохождения Security Gate и формирования SBOM.

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

#### 4.6.5. Cosign Sign & Verify

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

---

Документация будет дополняться по мере реализации и практической проверки новых возможностей.