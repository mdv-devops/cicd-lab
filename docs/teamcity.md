# Настройка TeamCity

[← Вернуться к основной документации](../README.md#teamcity-configuration)

TeamCity используется для автоматизации проверки исходного кода, запуска тестов, анализа безопасности, сборки и публикации Docker-образов.

В данном разделе описывается создание проекта и подключение GitHub к TeamCity.

<a name="toc"></a>

## Содержание

- [1. Создание проекта](#project-creation)
- [2. Подключение GitHub через VCS Root](#vcs-root)
  - [2.1. Создание VCS Root](#create-vcs-root)
  - [2.2. Настройка аутентификации](#vcs-authentication)
  - [2.3. Сохранение и проверка подключения](#test-vcs-connection)
- [3. Настройка Build Configurations](#build-configurations)

---

<a name="project-creation"></a>

## 1. Создание проекта

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

[← Вернуться к основной документации](../README.md#teamcity-configuration) | [↑ К содержанию](#toc)

---

**Шаг 2. Проверка общих настроек**

Откройте:

`Administration → Projects → global → General`

Убедитесь, что проект создан с указанными параметрами.

Дополнительные шаблоны настроек (`Default template` и `Enforced settings template`) в нашем примере не используются.

В дальнейшем внутри проекта будут созданы две Build Configurations:

1. **PR code reviewer** — сборка приложения, тестирование, анализ качества кода и поиск уязвимостей.
2. **Building & Deployment** — сборка Docker-образа, сканирование, формирование SBOM, публикация и цифровая подпись.

Каждая конфигурация будет настроена отдельно.

[← Вернуться к основной документации](../README.md#teamcity-configuration) | [↑ К содержанию](#toc)

---

<a name="vcs-root"></a>

## 2. Подключение GitHub через VCS Root

Для получения исходного кода из GitHub необходимо настроить **VCS Root** — подключение, через которое TeamCity получает доступ к Git-репозиторию и отслеживает изменения.

VCS Root создаётся на уровне проекта и может использоваться несколькими Build Configurations.

[← Вернуться к основной документации](../README.md#teamcity-configuration) | [↑ К содержанию](#toc)

---

<a name="create-vcs-root"></a>

### 2.1. Создание VCS Root

Откройте TeamCity и перейдите в настройки проекта:

`Administration → Projects → global → VCS Roots`

Нажмите `Create VCS Root` и выберите тип системы контроля версий `Git`.

В разделе `General Settings` укажите следующие параметры:

| Параметр | Значение |
|---|---|
| VCS root name | `cicd-lab-vcs` |
| VCS root ID | `Global_CicdLabVcs` |
| Fetch URL | `https://github.com/<github-owner>/<github-repository>.git` |
| Default branch | `refs/heads/preprod` |
| Branch specification | Оставить пустым |

**Fetch URL** — адрес Git-репозитория, из которого TeamCity будет получать исходный код.

**Default branch** — ветка, используемая TeamCity по умолчанию для отслеживания изменений и выполнения сборок.

**Branch specification** — позволяет дополнительно указать ветки, которые TeamCity должен отслеживать.

В нашем примере поле оставляем пустым. Обнаружение Pull Requests настроим отдельно в Build Configuration `1: PR code reviewer`.

[← Вернуться к основной документации](../README.md#teamcity-configuration) | [↑ К содержанию](#toc)

---

<a name="vcs-authentication"></a>

### 2.2. Настройка аутентификации

В разделе `Authentication Settings` выберите:

`Authentication method → Password / personal access token`

Заполните параметры:

| Параметр | Значение |
|---|---|
| Authentication method | `Password / personal access token` |
| Username | `<github-username>` |
| Password / access token | GitHub Personal Access Token |

Для подключения используется GitHub Personal Access Token (PAT).

Токен позволяет TeamCity обращаться к GitHub по HTTPS и получать исходный код репозитория.

Для чтения репозитория достаточно соответствующих разрешений на доступ к его содержимому. Дополнительные права следует предоставлять только при необходимости.

> **Важно:** токен не должен храниться в исходном коде проекта или публиковаться в документации. Используйте защищённое поле TeamCity для хранения учётных данных.

[← Вернуться к основной документации](../README.md#teamcity-configuration) | [↑ К содержанию](#toc)

---

<a name="test-vcs-connection"></a>

### 2.3. Сохранение и проверка подключения

После заполнения параметров проверьте доступность репозитория с помощью `Test connection`.

При успешном подключении сохраните VCS Root.

В списке VCS Roots проекта должен появиться:

`cicd-lab-vcs`

Созданный VCS Root будет использоваться для получения исходного кода в Build Configuration `1: PR code reviewer`.

Для Build Configuration `2: Building & Deployment` будет настроен отдельный VCS Root.

[← Вернуться к основной документации](../README.md#teamcity-configuration) | [↑ К содержанию](#toc)

---

<a name="build-configurations"></a>

## 3. Настройка Build Configurations

После создания проекта и настройки подключения к GitHub можно перейти к настройке CI/CD Pipeline.

| Build Configuration | Назначение | Документация |
|---|---|---|
| `1: PR code reviewer` | Проверка качества и безопасности исходного кода | [Настройка PR Code Reviewer](pr-code-reviewer.md) |
| `2: Building & Deployment` | Сборка, проверка, публикация и подпись Docker-образа | [Настройка Building & Deployment](building-and-deployment.md) |

[← Вернуться к основной документации](../README.md#teamcity-configuration) | [↑ К содержанию](#toc)

---