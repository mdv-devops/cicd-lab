# Настройка GitHub

[← Вернуться к основной документации](../README.md#git-workflow)

GitHub используется для хранения исходного кода, управления изменениями, работы с Pull Requests и защиты веток проекта.

В данном разделе описывается настройка правил защиты веток и обязательных автоматизированных проверок TeamCity.

## Содержание

- [1. Настройка защиты ветки preprod](#preprod-protection)
  - [1.1. Создание Ruleset](#create-ruleset)
  - [1.2. Настройка основных правил](#branch-rules)
  - [1.3. Настройка обязательного Pull Request](#pull-request-rules)
  - [1.4. Настройка обязательных проверок TeamCity](#required-status-checks)
  - [1.5. Сохранение правил](#save-ruleset)
- [2. Настройка защиты ветки main](#main-protection)

---

<a name="preprod-protection"></a>

## 1. Настройка защиты ветки `preprod`

Ветка `preprod` используется для объединения изменений разработчиков перед их переносом в `main`.

Для защиты ветки применяется GitHub Ruleset, который запрещает прямое внесение изменений, требует создания Pull Request и успешного прохождения автоматизированных проверок.

<a name="create-ruleset"></a>

### 1.1. Создание Ruleset

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

<a name="branch-rules"></a>

### 1.2. Настройка основных правил

В разделе `Branch rules` включите:

| Настройка | Назначение |
|---|---|
| Restrict deletions | Запрещает удаление ветки |
| Require a pull request before merging | Требует Pull Request для внесения изменений |
| Require status checks to pass | Требует успешных автоматизированных проверок |
| Block force pushes | Запрещает принудительную перезапись истории |

Остальные правила оставьте выключенными.

<a name="pull-request-rules"></a>

### 1.3. Настройка обязательного Pull Request

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

При объединении Pull Request все его коммиты сохраняются в истории целевой ветки.

<a name="required-status-checks"></a>

### 1.4. Настройка обязательных проверок TeamCity

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

**Различие между Status Check и Approve**

В процессе проверки Pull Request используются два независимых механизма:

| Механизм | Назначение |
|---|---|
| Status Check | Автоматизированная проверка качества и безопасности исходного кода в TeamCity |
| Approve | Ручное одобрение изменений участником проекта |

TeamCity публикует результат выполнения Pipeline в GitHub с помощью Commit Status Publisher.

Успешное выполнение Pipeline не заменяет ручное одобрение Pull Request, если оно требуется правилами защиты ветки.

Подробная настройка первого Pipeline описана в разделе [PR Code Reviewer](pr-code-reviewer.md).

<a name="save-ruleset"></a>

### 1.5. Сохранение правил

Нажмите `Save changes`.

После применения правил объединение Pull Request в `preprod` становится возможным только при выполнении всех обязательных условий:

- Успешное прохождение автоматизированных проверок TeamCity.
- Получение необходимого количества ручных одобрений.
- Завершение всех обсуждений изменений.

Прямые изменения, удаление ветки и принудительная перезапись истории будут запрещены.

Таким образом, GitHub совместно с TeamCity обеспечивает контроль внесения изменений в интеграционную ветку проекта.

---

<a name="main-protection"></a>

## 2. Настройка защиты ветки `main`

Настройка защиты ветки `main` будет описана после реализации процесса развёртывания приложения в Kubernetes, выполнения проверок после развёртывания и определения механизма автоматического создания Pull Request из `preprod` в `main`.

---

[← Вернуться к основной документации](../README.md#git-workflow)