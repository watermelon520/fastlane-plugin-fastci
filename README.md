
# fastlane-plugin-fastci

[![fastlane Plugin Badge](https://rawcdn.githack.com/fastlane/fastlane/master/fastlane/assets/plugin-badge.svg)](https://rubygems.org/gems/fastlane-plugin-fastci)

一个集成 iOS 打包脚本与多种自动化操作的 Fastlane 聚合插件。
简单快速的集成，5 分钟即可上手。
配合 Jenkins 实现高度自定义。

---

## 安装方法

1、安装 [python3](https://www.python.org/downloads/macos/)

2、安装 [homebrew](https://brew.sh/)

3、安装并初始化 [fastlane](https://docs.fastlane.tools/getting-started/ios/setup/)

4、添加插件 ` fastlane add_plugin fastci `

5、更新插件 ` fastlane update_plugins `

---

## 使用方法

参考 [Fastfile](fastlane/Fastfile)，将[配置模板](fastlane/.env.default.example)复制为项目中的 `fastlane/.env.default`，再填写项目参数；
项目根目录新建 ` PACKAGE_FILE_FOLDER_NAME ` 配置对应名字文件夹，将描述文件、p12 证书、p8 密钥等文件放入该文件夹下；
然后终端进入项目根目录即可使用 ` fastlane `

如果是同一个 xcworkspace 多 xcodeproj 的情况，可以采用多配置文件的方式。同样参考[配置模板](fastlane/.env.default.example)，根据多个 xcodeproj 创建配置文件 ` .env.project1 `、` .env.project2 `；运行配置不保留 `.example` 后缀，名字也不能是 ` .env.project1.default `；
不同的配置文件配置不同的 ` PROJECT_NAME `；
使用本仓库示例 Fastfile 时，指定环境文件执行 `bundle exec fastlane ios ipaPackage --env project1`。

### 使用后会在项目根目录生成文件夹

可以自行在 ` .gitignore ` 中设置忽略等级 

```
fastlane_cache/ # 插件缓存文件夹
├── build_logs/ # 编译日志
├── html/ # 各种检查报告
├── temp/ # 临时文件
├── build_cache.txt # build 自动递增缓存
└── commit_cache.txt # git commit 缓存
```

## 支持功能与使用示例

### 1. 自动打包
功能：自动编译并导出 ipa 包，支持多种打包方式和集成多项检查。
生成完的 ipa 会放在桌面上，非 ` app-store ` 配置了蒲公英或 fir 参数会自动上传蒲公英或 fir。` app-store ` 和 ` testFlight ` 配置了商店参数会自动上传商店。
配置了 Sentry 参数会自动上传符号表。
配置了 Zealot 参数的非商店包也可自动上传，详见下方 Zealot 配置。
App Store 元数据、截图和更新说明默认不上传，必须单独开启商店资源总开关并配置资源 JSON；详见 [App Store 元数据与截图](#app-store-resources)。TestFlight 不使用商店资源配置。

` build `: 不指定的话内部有递增逻辑，格式为 ` 20250905.15（日期+当天包的次数） `

` version `: 在 Xcode13 之后创建的项目，不再支持脚本修改。需要兼容请在 ` Build settings ` 中将 ` GENERATE_INFOPLIST_FILE ` 设置为 ` NO `

其他参数可以使用 ` fastlane action package ` 查看

```ruby
package(
	configuration: "Debug", # 编译环境 Release/Debug
	export_method: "development", # 打包方式 ad-hoc, enterprise, app-store, development, testFlight
	version: nil, # 指定 version
	build: nil, # 指定 build 号
	is_analyze_swiftlint: false, # 是否代码分析
	is_detect_duplicity_code: false, # 是否检测重复代码
	is_detect_unused_code: false, # 是否检测未使用代码
	is_detect_unused_image: false, # 是否检测未使用图片
	changelog: options[:changelog], # fir / Zealot 更新日志，也是各平台钉钉通知的更新说明
	app_store_resources_enabled: options[:app_store_resources_enabled], # 总开关；未传时读取 APP_STORE_RESOURCES_ENABLED，默认 false
	app_store_resources_config_path: options[:app_store_resources_config_path], # 未传时读取 APP_STORE_RESOURCES_CONFIG_PATH
	release_notes: options[:release_notes], # JSON 字符串，例如 '{"zh-Hans":"修复问题","en-US":"Bug fixes"}'；仅资源功能开启且上传 metadata 时生效
	is_notice_dingding: options[:is_notice_dingding] # 配置钉钉token了，通过该参数控制是否发送通知
)
```

### 2. SwiftLint 静态代码分析
功能：依赖 ` SwiftLint ` 对项目代码进行静态分析，生成分析报告。
使用前需要参考自定义 [` .swiftlint.yml `](/.swiftlint.yml) 文件，并将该文件放到项目根目录。

` commit_hash `: 上一次提交哈希, 会比较该哈希到最新哈希之间的文件

```ruby
analyze_swiftlint(
	is_all: true, # 是否检查所有文件，默认 true
	configuration: "Debug", # 构建配置，Debug/Release
	commit_hash: nil # 指定 commit hash，仅检查变更文件
)
```

### 3. 检测重复代码
功能：检测项目中的重复代码，生成分析报告。
使用前需要参考自定义 [` .periphery.yml `](/.periphery.yml) 文件，并将该文件放到项目根目录。

` commit_hash `: 上一次提交哈希, 会比较该哈希到最新哈希之间的文件

```ruby
detect_duplicity_code(
	is_all: true, # 是否检查所有文件，默认 true
	commit_hash: nil # 指定 commit hash，仅检查变更文件
)
```

### 4. 检测未使用代码
功能：检测项目中未被使用的代码，生成分析报告。
默认只支持 ` Debug `，需要支持 ` Release ` 请在 ` Build settings ` 中将 ` Enable Index-While-Building Functionality ` 设置为 ` Yes `。

```ruby
detect_unused_code(
	configuration: "Debug" # 构建配置，Debug/Release
)
```

### 5. 检测未使用图片资源
功能：检测项目中未被使用的图片资源，生成分析报告。

```ruby
detect_unused_image(
    exclude: nil # 要排除的路径，多个路径用逗号分隔。默认会排除 Carthage 和 Pods 目录
)
```

---

<a id="app-store-resources"></a>

### 6. App Store 元数据与截图（配置驱动，仅 iOS）

通过独立 `app_store_resources` Action 管理商店名称、副标题、描述、关键词、更新说明、宣传文本、支持/隐私链接、分类、审核信息及截图，沿用 Fastlane 的 metadata 目录格式。也可以接入现有 `package` / `upload_store` 流程：先上传 IPA，再上传配置指定的资源，最后按需选择 Build、提交审核。

**商店资源总开关默认关闭，必须设置 `APP_STORE_RESOURCES_ENABLED=true`，或显式传入 `app_store_resources_enabled: true` 才能使用。** 只配置 JSON 路径、资源目录、`metadata_changed` 或 `release_notes` 均不会开启功能。关闭时，`package` / `upload_store` 仅上传 IPA，明确跳过元数据、截图和更新说明；独立 `app_store_resources` 直接跳过，不读取资源配置、不认证、不上传下载、不选择构建或提交审核。TestFlight 和测试包不使用商店资源流程。

| 入口 | 用途 | 开启后的配置要求 |
| --- | --- | --- |
| `package` | 打包并上传 IPA，再执行资源流程 | 必须提供 `app_store_resources_config_path`；自动传入本次 Bundle ID、版本和 Build |
| `upload_store` | 上传已有 gym 产物，再执行资源流程 | 必须提供 `app_store_resources_config_path`；需要选择构建时自行提供版本与 Build |
| `app_store_resources` | 独立更新商店资源，不上传 IPA | 使用 `config_path` 或直接传入资源参数 |

#### 配置与认证

将 [`fastlane/app_store_resources.example.json`](fastlane/app_store_resources.example.json) 复制到业务项目，例如 `fastlane/app_store_resources.json`，修改 Bundle ID、版本和资源路径。使用**扁平 JSON**；项目自有的嵌套 Jenkins 配置需要先转换为模板中的字段。

```dotenv
# 总开关，未设置或 false 时均不能使用商店资源功能。
APP_STORE_RESOURCES_ENABLED=true
# 相对路径以执行 Action 时的项目根目录为基准，不以 JSON 所在目录为基准。
APP_STORE_RESOURCES_CONFIG_PATH=fastlane/app_store_resources.json

# 认证方式一：App Store Connect API Key JSON（本机或 CI 密钥文件）。
APP_STORE_CONNECT_API_KEY_PATH=/secure/app-store-connect.json

# 认证方式二：沿用 CONNECT_KEY_ID、CONNECT_ISSUER_ID 和证书目录下的 P8。
# 可选 APP_STORE_CONNECT_P8_PATH=/secure/AuthKey_KEYID.p8 覆盖默认路径。
```

| 环境变量 | 默认值 | 说明 |
| --- | --- | --- |
| `APP_STORE_RESOURCES_ENABLED` | `false` | 商店资源总开关；未设置与关闭效果相同 |
| `APP_STORE_RESOURCES_CONFIG_PATH` | 未设置 | 资源 JSON 路径；`package` / `upload_store` 开启资源功能后必填 |
| `APP_STORE_CONNECT_API_KEY_PATH` | 未设置 | 认证用 API Key JSON 路径，与资源 JSON 是两个不同文件 |
| `APP_STORE_CONNECT_P8_PATH` | 未设置 | 自定义 P8 路径，配合 `CONNECT_KEY_ID`、`CONNECT_ISSUER_ID` 使用；不配置时从 `PACKAGE_FILE_FOLDER_NAME/AuthKey_<KEY_ID>.p8` 读取 |

认证方式二的环境配置示例：

```dotenv
CONNECT_KEY_ID=your-key-id
CONNECT_ISSUER_ID=your-issuer-id
APP_STORE_CONNECT_P8_PATH=/secure/AuthKey_your-key-id.p8
```

使用 P8 方式时不设置 `APP_STORE_CONNECT_API_KEY_PATH`。资源 JSON 或显式参数中的认证优先，其次是环境中的 API Key JSON、已有 lane 的 API Key，最后使用 P8 配置。已有 API Key 可直接复用，无需每次重新创建。

资源配置示例：

```json
{
  "app_identifier": "com.example.app",
  "app_version": "1.0.0",
  "metadata_path": "fastlane/metadata",
  "screenshots_path": "fastlane/screenshots",
  "metadata_changed": true,
  "screenshots_changed": false,
  "upload_metadata_on_new_version": true,
  "select_build": false,
  "submit_for_review": false,
  "automatic_release": false
}
```

#### 元数据与截图目录

元数据内容存放于文本文件，语言目录名与 App Store Connect 语言代码对应，例如：

```text
fastlane/metadata/
├── copyright.txt
├── primary_category.txt
├── review_information/notes.txt
├── zh-Hans/
│   ├── name.txt
│   ├── subtitle.txt
│   ├── description.txt
│   ├── keywords.txt
│   ├── promotional_text.txt
│   ├── support_url.txt
│   ├── privacy_url.txt
│   └── release_notes.txt
└── en-US/
    ├── description.txt
    └── release_notes.txt
fastlane/screenshots/zh-Hans/1.png
```

只更新文案时设置 `metadata_changed=true`、`screenshots_changed=false`；只更新截图时设置 `metadata_changed=false`、`screenshots_changed=true`。如果还要禁止新版本自动补传文案，需同时设置 `upload_metadata_on_new_version=false`。上传的资源类别必须有非空目录，截图支持 `.png`、`.jpg`、`.jpeg`，图片格式和设备尺寸由 deliver 校验。

#### Action 与命令行调用

总开关开启后，在已有打包 lane 中配置资源路径即可使用；也可以显式传入开关和路径：

```ruby
package(
  export_method: "app-store",
  app_store_resources_enabled: true,
  app_store_resources_config_path: "fastlane/app_store_resources.json"
)

# 只更新商店资源，不重新构建、不上传 IPA。
app_store_resources(
  app_store_resources_enabled: true,
  config_path: "fastlane/app_store_resources.json"
)

# 已有 gym 产物时，上传 IPA 后更新资源。
upload_store(
  app_store_resources_enabled: true,
  app_store_resources_config_path: "fastlane/app_store_resources.json"
)
```

总开关只通过环境变量或 Action 参数配置，不放在资源 JSON 中；显式 Action 参数优先于环境变量，因此传 `app_store_resources_enabled: false` 可以关闭环境中已开启的功能。`package` / `upload_store` 开启后必须同时提供资源配置路径，否则报错；独立 Action 开启后也可直接传入资源参数。

使用本仓库示例 [Fastfile](fastlane/Fastfile) 时，可以在业务项目根目录运行以下命令。命令会执行实际上传，运行前应替换配置中的示例值并准备对应资源和认证文件。

```bash
# 打包、上传 App Store IPA，再更新资源；开关、资源路径和认证读取环境文件。
bundle exec fastlane ios ipaPackage export_method:app-store

# 只更新商店资源；开关、资源路径和认证读取环境文件。
bundle exec fastlane ios appStoreResources

# 也可以在调用时明确开启，并为独立资源 lane 指定配置文件。
bundle exec fastlane ios appStoreResources app_store_resources_enabled:true config_path:fastlane/app_store_resources.json

# 本次仅上传 IPA，即使环境文件已开启资源功能也不更新资源。
bundle exec fastlane ios ipaPackage export_method:app-store app_store_resources_enabled:false
```

多项目环境可在命令后追加 `--env project1`。示例 lane 名是 `ipaPackage` 和 `appStoreResources`；已有项目使用自定义 lane 时，在对应 lane 中调用上面的 Action 即可。

#### 资源 JSON 参数

| JSON 参数 | 默认值 | 用途 |
| --- | --- | --- |
| `app_identifier` | `BUNDLE_ID` | 应用的 Bundle ID，最终不能为空 |
| `app_version` | 未设置 | 目标商店版本；选择构建或提交审核时必填 |
| `build_number` | 未设置 | 精确 Build 号；选择构建或提交审核时必填，使用字符串 |
| `metadata_path` / `screenshots_path` | `fastlane/metadata` / `fastlane/screenshots` | 相对路径以项目根目录为基准；未启用的资源类别不要求目录存在 |
| `metadata_changed` | `true` | 上传 metadata；设为 `false` 可跳过 |
| `screenshots_changed` | `false` | 上传截图，需显式开启 |
| `upload_metadata_on_new_version` | `true` | 指定 `app_version` 且目标可编辑版本不存在时补传 metadata，即使 `metadata_changed=false` |
| `download_missing_metadata` / `download_missing_screenshots` | `false` | 从 App Store Connect 初始化空的资源目录；不覆盖已有本地资源 |
| `use_live_version` | `false` | 初始化截图时使用线上版本 |
| `sync_screenshots` / `overwrite_screenshots` | `false` | 同步或替换远端截图，仅 `screenshots_changed=true` 时生效；同步还需 `FASTLANE_ENABLE_BETA_DELIVER_SYNC_SCREENSHOTS=true` |
| `select_build` | `false` | 按 `app_version` + `build_number` 选择处理完成的精确构建 |
| `wait_for_build_processing` | `true` | 选择构建前等待 Apple 处理 |
| `build_processing_timeout` / `build_processing_poll_interval` | `3600` / `30` | 等待超时和轮询间隔，单位秒 |
| `build_processing_retry_limit` / `build_processing_retry_interval` | `3` / `15` | 临时网络错误的重试次数和间隔，仍受总超时约束 |
| `submit_for_review` / `automatic_release` | `false` | 显式开启审核提交、审核通过后自动发布 |
| `release_notes` | 未设置 | 按语言提供更新说明的 JSON 对象，覆盖对应 `release_notes.txt` |
| `submission_information` | 未设置 | 提交审核所需的出口合规等信息 |
| `api_key_path` / `api_key` | 未设置 | API Key JSON 路径或 Key Hash，二者互斥 |
| `username` | 未设置 | 使用 Apple ID 登录时的用户名 |
| `platform` | `ios` | 当前资源 Action 仅支持 iOS |
| `force` | `true` | 跳过 deliver 的 HTML 预览确认 |

配置优先级为**显式 Action 参数 > JSON > 默认值**。`package` 会用本次实际的 Bundle ID、版本号和 Build 号覆盖 JSON，避免选择旧构建；独立调用需要自行填写目标版本和构建号。开启 `select_build` 或 `submit_for_review` 时，两者均为必填。传给 `package` / `upload_store` 的 `release_notes` 仍沿用原 JSON 字符串格式，仅在上传 metadata 时生效。

#### 常见使用场景

以下资源操作均以总开关已开启为前提。资源的变更开关由项目或 CI 设置，插件不自行运行 Git 差异检测。

| 场景 | 关键配置 |
| --- | --- |
| 只上传 IPA | 总开关关闭；不执行资源流程 |
| 只修改文案 | `metadata_changed=true`，`screenshots_changed=false`，调用独立资源 Action |
| 只更新截图 | `metadata_changed=false`，`screenshots_changed=true`，`upload_metadata_on_new_version=false` |
| 上传 IPA 后绑定本次构建 | 调用 `package`，资源 JSON 中配置 `select_build=true`；版本和 Build 使用本次产物值 |
| 仅选择已有构建 | 独立调用时提供 `app_version`、`build_number`，设置 `select_build=true`、两个 `*_changed=false`、`upload_metadata_on_new_version=false` |
| 提交审核 | 设置 `submit_for_review=true` 并提供版本与 Build；先确认构建处理成功并绑定，再提交审核 |

`select_build`、`submit_for_review`、`automatic_release` 均默认关闭。等待处理超时、构建处理失败或可编辑版本不匹配时会报错，不会改选其他构建。`automatic_release` 只控制本次审核通过后的发布方式，需配合 `submit_for_review=true` 使用。

首次只下载资源时，可以直接调用：

```ruby
app_store_resources(
  app_store_resources_enabled: true,
  app_identifier: "com.example.app",
  metadata_path: "fastlane/metadata",
  screenshots_path: "fastlane/screenshots",
  metadata_changed: false,
  screenshots_changed: false,
  upload_metadata_on_new_version: false,
  download_missing_metadata: true,
  download_missing_screenshots: true,
  use_live_version: true,
  select_build: false,
  submit_for_review: false,
  automatic_release: false
)
```

此例的认证仍读取环境配置，截图使用已有线上版本；尚无线上版本时，需使用可编辑版本并设置 `use_live_version=false`。下载只初始化空的资源类别，不覆盖本地已有文案或截图。

#### 旧用法与失败处理

- 旧 lane 仅传 `release_notes` 时，现在只上传 IPA；要上传更新说明，必须开启总开关并提供资源配置，且允许上传 metadata。
- 总开关关闭时，资源路径和资源子开关不会生效，`Deliverfile` 中开启截图同步也不会绕过 IPA 上传阶段的禁用设置。
- `package` 开启资源功能但未配置路径时，会在构建前报错；`upload_store` 会在认证或上传前报错。
- 开启后的 JSON 格式错误、未知字段、无效参数类型或空资源目录会终止任务。若资源上传失败，后续构建选择和审核提交不会继续；已成功上传的 IPA 不会回滚。
- TestFlight、Zealot、Fir 和蒲公英不使用商店资源总开关。

仅查看参数说明、不会触发上传的命令：

```bash
bundle exec fastlane action package
bundle exec fastlane action upload_store
bundle exec fastlane action app_store_resources
```

目录格式和字段遵循 [Fastlane deliver 文档](https://docs.fastlane.tools/actions/deliver/)。

### 7. Zealot（仅 iOS）

通过官方 [fastlane-plugin-zealot](https://github.com/tryzealot/fastlane-plugin-zealot) 封装以下独立 Action：

| Action | 用途 |
| --- | --- |
| `upload_zealot` | 上传 IPA，返回版本与下载地址 |
| `upload_zealot_dsym` | 上传 iOS dSYM，支持 zip 或 xcarchive |
| `check_zealot_version` | 按 Bundle ID、版本号或 commit 查询版本 |
| `sync_zealot_devices` | 将 Apple 开发者账号中的 iOS 设备同步到 Zealot |

在环境文件或 CI 环境变量中配置：

```dotenv
ZEALOT_ENDPOINT=https://zealot.example.com
ZEALOT_TOKEN=your-user-token
ZEALOT_CHANNEL_KEY=your-ios-channel-key
ZEALOT_UPLOAD_DSYM=false
```

`package` 与 Fir 一样按 token 判断是否上传：配置 `ZEALOT_TOKEN` 后，自动上传 `development`、`ad-hoc`、`enterprise` 包；token 留空时跳过。上传时必须同时提供 `ZEALOT_ENDPOINT` 和 `ZEALOT_CHANNEL_KEY`。`app-store` 和 `testFlight` 保持原上传流程。

```ruby
package(
  export_method: "development",
  is_upload_zealot_dsym: true,  # 默认 false；仅 IPA 上传成功后执行
  changelog: "iOS 更新说明"
)
```

也可以单独调用，不需要重新构建：

```ruby
result = upload_zealot(file: "./App.ipa", changelog: "iOS 更新说明")
# result：app_id、release_id、release_url、install_url、qrcode_url

upload_zealot_dsym(zip_file: "./App.app.dSYM.zip")
# 或指定 path: "./App.xcarchive"；均未指定时使用本次 gym 产物。

exists = check_zealot_version(
  bundle_id: "com.example.app",
  release_version: "1.0",
  build_version: "1"
)
# 也可用 git_commit 替代 release_version / build_version。

sync_zealot_devices(api_key_path: "./app_store_connect_api_key.json")
# 也可使用 username / team_id；设备同步不会在 package 中自动执行。
```

请求失败默认终止 lane，可传 `fail_on_error: false` 或设置 `ZEALOT_FAIL_ON_ERROR=false` 继续执行。版本查询返回 `true`（存在）、`false`（不存在）、`nil`（请求失败且允许继续）；设备同步返回 `total`、`succeeded`、`failed`。token 在请求摘要中始终隐藏。

上传参数支持官方的 `password`、`timeout`、`verify_ssl`、`branch`、`git_commit` 等选项，使用 `bundle exec fastlane action upload_zealot` 查看。示例 Fastfile 也提供 `uploadZealot`、`uploadZealotDsym`、`checkZealotVersion`、`syncZealotDevices` 四个 lane。

依赖兼容：Zealot 的 `debug_file` 依赖 `ruby-macho < 3`，不能与 CocoaPods 1.17（依赖 4.x）放在同一 bundle。此类工程应将 CocoaPods 放入独立 Gemfile；使用 Faraday 1 的 Fastlane 工程还应将 `faraday-net_http` 限制为 `~> 1.0`。

### 8. 钉钉通知

`package` 使用统一的 Markdown 模板发送分发结果、失败及检查结果。配置 `DINGDING_TOKEN` 后默认开启，传入 `is_notice_dingding: false` 可关闭本次流程的全部通知。机器人配置参考[钉钉自定义机器人文档](https://open.dingtalk.com/document/robots/custom-robot-access)，关键词可设为 `iOS`。

```dotenv
DINGDING_TOKEN=
DINGDING_INCLUDE_INSTALL_PASSWORD=true
DINGDING_TESTFLIGHT_URL=
DINGDING_APP_STORE_URL=
```

| 配置 | 默认值 | 用途 |
| --- | --- | --- |
| `DINGDING_TOKEN` | 未设置 | 群机器人的 `access_token`；未配置时不发送 |
| `is_notice_dingding` | `true` | `package` 参数；`false` 优先于 Token 配置 |
| `DINGDING_INCLUDE_INSTALL_PASSWORD` | `true` | 是否展示蒲公英 / fir 的安装密码；`false` 时隐藏 |
| `DINGDING_TESTFLIGHT_URL` | 未设置 | TestFlight 公开测试邀请链接，配置后展示 |
| `DINGDING_APP_STORE_URL` | 未设置 | App Store 线上应用页面，配置后展示 |

#### 统一内容与发送时机

标题为 `应用 Scheme iOS · 平台 · 状态`。各平台均包含应用、Bundle ID、分发平台、状态、实际版本、Build、打包方式、构建配置、累计耗时和通知时间；时间包含构建机器的时区偏移。`changelog` 有值时追加更新说明，最多展示 1,000 个字符。缺失的可选字段与链接不展示。

更新说明保留输入的逐行内容，LF / CRLF 换行会转换为 Markdown 强制换行，避免多条 Git 提交显示成一段；该格式转换仅用于钉钉展示，不修改上传平台收到的日志原文。

二维码由构建机下载后，以 `data:image/...;base64,...` 内嵌到同一条 Markdown 通知，保留「打开二维码」链接。接受 PNG / JPEG / GIF，单图上限 8 KB，连接超时 5 秒、下载总超时 15 秒；下载失败、格式不符或超过上限时只展示链接，不中断打包。Base64 展示采用当前使用环境已验证的方式；[钉钉官方消息类型文档](https://open.dingtalk.com/document/orgapp/custom-bot-send-message-type)未明确承诺 Data URL 的跨客户端支持。

- IPA 构建并复制完成后仅记录终端日志，不发送钉钉成功通知。
- 蒲公英、fir、Zealot、TestFlight 和 App Store 在各自上传结束后发送一次平台结果；同时上传多个平台时，每个平台各一条。
- 商店包缺少上传配置时发送「未上传」，说明 IPA 已生成；未配置测试分发平台且未执行检查时，构建成功不发送通知。
- 构建、分发、符号上传或检查抛出异常时，发送当前平台和失败阶段，随后保留原有异常处理。原始异常详情仍在构建日志中。
- Zealot 关闭 `fail_on_error` 后未返回发布结果时，发送「上传未完成」，按原配置继续流程。
- 只有实际执行了代码检查，才发送检查项目清单；这表示检查执行完成，问题详情查看报告。App Store / TestFlight 跳过检查时不发送检查完成通知。
- 钉钉发送超时、HTTP 失败或机器人拒绝消息时，只记录提示，不改变打包结果。不再发送「测试一下」。

发送使用系统 `/usr/bin/curl`，保留 HTTPS 证书校验，连接超时 5 秒、整个请求超时 15 秒；Token 与正文通过标准输入传入，不出现在命令参数中。终端会记录发送开始及成功，失败时区分 curl 退出码、HTTP 状态码和钉钉 `errcode`，不打印凭据或原始响应。

通知由 `package` 统一编排；直接调用 `upload_pgy`、`upload_fir`、`upload_zealot`、`upload_store` 或 `app_store_resources` 不额外发送这套通知。

#### 各分发平台内容

下面五份示例使用同一套公共字段；安装密码、链接、二维码只在配置或上传结果提供时出现。示例中的更新说明来自 `package(changelog: "修复问题，优化体验")`，不会自动读取 metadata 目录中的文案。

**蒲公英**：安装页面、安装二维码、安装密码。地址使用上传接口返回的实际地址。

```text
📦 ExampleApp iOS · 蒲公英 · 上传完成
应用：ExampleApp
Bundle ID：com.example.app
分发平台：蒲公英
状态：上传完成
版本：1.2.3
Build：42
打包方式：ad-hoc
构建配置：Release
安装密码：example-password
累计耗时：180 秒
通知时间：2026-11-03 12:00:00 +08:00
[安装页面]
[安装二维码]
更新说明：修复问题，优化体验
```

**fir**：安装页面、安装密码。当前上传接口不提供二维码，因此不生成二维码链接。

```text
📦 ExampleApp iOS · fir · 上传完成
应用：ExampleApp
Bundle ID：com.example.app
分发平台：fir
状态：上传完成
版本：1.2.3
Build：42
打包方式：ad-hoc
构建配置：Release
安装密码：example-password
累计耗时：190 秒
通知时间：2026-11-03 12:00:10 +08:00
[安装页面]
更新说明：修复问题，优化体验
```

**Zealot**：Release ID、版本详情、安装页面、安装二维码，以及 dSYM 是否上传。开启 dSYM 上传后，等待该步骤结束再发送此平台的结果。

```text
📦 ExampleApp iOS · Zealot · 上传完成
应用：ExampleApp
Bundle ID：com.example.app
分发平台：Zealot
状态：上传完成
版本：1.2.3
Build：42
打包方式：ad-hoc
构建配置：Release
Release ID：42
dSYM：已上传
累计耗时：200 秒
通知时间：2026-11-03 12:00:20 +08:00
[版本详情] [安装页面]
[安装二维码]
更新说明：修复问题，优化体验
```

**TestFlight**：App Store Connect 入口、可选测试邀请；明确区分 IPA 上传和 Apple 后续处理。邀请链接不会因为本次上传而保证新构建已可测试。

```text
📦 ExampleApp iOS · TestFlight · 上传完成
应用：ExampleApp
Bundle ID：com.example.app
分发平台：TestFlight
状态：上传完成
版本：1.2.3
Build：42
打包方式：testFlight
构建配置：Release
说明：IPA 已上传，尚未等待 Apple 处理完成；测试可用性请在 App Store Connect 确认。
累计耗时：240 秒
通知时间：2026-11-03 12:01:00 +08:00
[App Store Connect] [TestFlight 测试邀请]
更新说明：修复问题，优化体验
```

**App Store**：App Store Connect 入口、可选线上页面，以及本次元数据、截图、构建选择、提交审核的执行结果。资源总开关关闭时显示「商店资源：未开启，仅上传 IPA」；开启时如下例。

```text
📦 ExampleApp iOS · App Store · 上传完成
应用：ExampleApp
Bundle ID：com.example.app
分发平台：App Store
状态：上传完成
版本：1.2.3
Build：42
打包方式：app-store
构建配置：Release
说明：上传完成不代表审核通过或已上线；线上页面可能仍为旧版本。
元数据：已上传
截图：未上传
构建选择：已选择本次 Build
提交审核：已提交
累计耗时：360 秒
通知时间：2026-11-03 12:03:00 +08:00
[App Store Connect] [App Store 线上页面]
更新说明：修复问题，优化体验
```

商店资源流程失败时不会发送上述成功消息，而是发送「执行失败」，注明失败阶段和 IPA 是否已经上传；通知本身不会开启商店资源功能。

---

## 发布到 RubyGems

工作流位于 [`.github/workflows/release.yml`](.github/workflows/release.yml)。使用 `1.0.0` 这样的纯版本标签，无需 `v` 前缀。推送数字开头的标签后，自动校验标签与 `lib/fastlane/plugin/fastci/version.rb` 中的 `VERSION` 完全一致，检查 Ruby 语法、构建 gem 并发布到 RubyGems。

首次使用需完成一次 [RubyGems Trusted Publishing 配置](https://guides.rubygems.org/trusted-publishing/)：

用 gem 所有者账号打开 [fastlane-plugin-fastci](https://rubygems.org/gems/fastlane-plugin-fastci)，进入 **Trusted publishers → Create**，填写：

| 字段 | 值 |
| --- | --- |
| Repository owner | `watermelon520` |
| Repository name | `fastlane-plugin-fastci` |
| Workflow filename | `release.yml` |
| Environment | 留空（可选） |

工作流使用官方 OIDC 短期凭据，不需要配置 `RUBYGEMS_API_KEY` 或创建 GitHub Environment。工作流文件在当前仓库内，Workflow Repository 两项留空。若以后设置 Environment，RubyGems 配置与工作流的 `environment` 必须保持一致。

每次发布先修改 `VERSION`，执行 `bundle install` 同步 `Gemfile.lock`，并提交本次拟发布的代码和工作流。然后推送对应标签，例如版本更新为 `0.0.41` 后：

```bash
git push origin main
git tag -a 0.0.41 -m "Release 0.0.41"
git push origin 0.0.41
```

到 GitHub **Actions → Release to RubyGems** 查看结果。已发布版本不能覆盖；失败重跑前先确认该版本是否已经发布。只有打入标签提交的文件会被发布，本地未提交改动不会包含在内。

## 贡献与支持

如需更多帮助或贡献，请提交 Issue 或 PR。
