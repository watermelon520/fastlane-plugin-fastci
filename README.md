
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

参考 [` Fastfile `](fastlane/Fastfile) 和 [` .env.default `](fastlane/.env.default) 替换项目内 fastlane 文件夹下文件；
项目根目录新建 ` PACKAGE_FILE_FOLDER_NAME ` 配置对应名字文件夹，将描述文件、p12 证书、p8 密钥等文件放入该文件夹下；
然后终端进入项目根目录即可使用 ` fastlane `

如果是同一个 xcworkspace 多 xcodeproj 的情况，可以采用多配置文件的方式。同样也是参考 [` .env.default `](fastlane/.env.default) 根据多个 xcodeproj 创建多个配置文件 ` .env.project1 ` 、 ` .env.project2 `，注意文件的隐藏扩展，名字不能是 ` .env.project1.default `；
不同的配置文件配置不同的 ` PROJECT_NAME `；
执行的时候指定环境文件 ` fastlane --env project1 package ` 来运行


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
	changelog: options[:changelog], # fir 更新日志
    release_notes: options[:release_notes], # 配合 jenkins 传参上传 appstore 格式为 { \"zh-Hans\": \"修复问题\", \"en-US\": \"bugfix\"} JSON 字符串 
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

### 6. Zealot（仅 iOS）

通过官方 [fastlane-plugin-zealot](https://github.com/tryzealot/fastlane-plugin-zealot) 封装以下独立 Action：

| Action | 用途 |
| --- | --- |
| `upload_zealot` | 上传 IPA，返回版本与下载地址 |
| `upload_zealot_dsym` | 上传 iOS dSYM，支持 zip 或 xcarchive |
| `check_zealot_version` | 按 Bundle ID、版本号或 commit 查询版本 |
| `sync_zealot_devices` | 将 Apple 开发者账号中的 iOS 设备同步到 Zealot |

在本机环境文件或 CI 密钥中配置，真实 token 不要提交到仓库：

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

每次发布先修改 `VERSION`，执行 `bundle install` 同步 `Gemfile.lock`，并提交本次拟发布的代码和工作流。然后推送对应标签，例如版本更新为 `0.0.30` 后：

```bash
git push origin main
git tag -a 0.0.30 -m "Release 0.0.30"
git push origin 0.0.30
```

到 GitHub **Actions → Release to RubyGems** 查看结果。已发布版本不能覆盖；失败重跑前先确认该版本是否已经发布。只有打入标签提交的文件会被发布，本地未提交改动不会包含在内。

## 贡献与支持

如需更多帮助或贡献，请提交 Issue 或 PR。
