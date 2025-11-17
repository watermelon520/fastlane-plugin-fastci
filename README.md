
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

如果是同一个 xcworkspace 多 xcodeproj 的情况，可以采用多配置文件的方式。同样也是参考 [` .env.default `](fastlane/.env.default) 根据多个 xcodeproj 创建多个配置文件 ` .env.project1 ` 、 ` .env.project2 `；
执行的时候指定环境文件 ` fastlane package --env project1 ` 来运行


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
    release_notes: options[:release_notes] # 配合 jenkins 传参上传 appstore 格式为 { \"zh-Hans\": \"修复问题\", \"en-US\": \"bugfix\"} JSON 字符串 
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

## 贡献与支持

如需更多帮助或贡献，请提交 Issue 或 PR。
