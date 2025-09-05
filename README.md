
# fastlane-plugin-fastci

[![fastlane Plugin Badge](https://rawcdn.githack.com/fastlane/fastlane/master/fastlane/assets/plugin-badge.svg)](https://rubygems.org/gems/fastlane-plugin-ld)

一个集成 iOS CI 与多种自动化操作的 Fastlane 集合插件。
简单快速的集成，5 分钟即可上手。
配合 Jenkins 实现高度自定义。

---

## 安装方法

```shell
fastlane add_plugin fastci
```

---

## 使用方法

需要 python3 环境；初始化 fastlane 环境；
然后参考项目 fastlane 文件夹内编写 Fastfile 和 .env.default 文件替换项目内文件
最后项目根目录就可以开始使用了 ` fastlane `

---

## 支持功能与使用示例

### 1. 自动打包
功能：自动编译并导出 ipa 包，支持多种打包方式和集成多项检查。
生成完的 ipa 会放在桌面上，非 app-store 配置了蒲公英参数会自动上传蒲公英，app-store 配置了商店参数会自动上传蒲公英。

build：不指定的话内部有递增逻辑，格式为 20250905.15（日期+当天包的次数）

version：在 Xcode13 之后创建的项目，不再支持脚本修改。需要兼容请在 Build settings 中将 GENERATE_INFOPLIST_FILE 设置为 NO

```ruby
package(
	configuration: "Debug", # 编译环境 Release/Debug
	export_method: "development", # 打包方式 ad-hoc, enterprise, app-store, development
	version: nil, # 指定 version
	build: nil, # 指定 build 号
	is_analyze_swiftlint: false, # 是否代码分析
	is_detect_duplicity_code: false, # 是否检测重复代码
	is_detect_unused_code: false, # 是否检测未使用代码
	is_detect_unused_image: false # 是否检测未使用图片
)
```

### 2. SwiftLint 静态代码分析
功能：依赖 SwiftLint 对项目 Swift 代码进行静态分析，生成分析报告。
使用前需要参考自定义 .swiftlint.yml 文件，并将该文件放到项目根目录。

```ruby
analyze_swiftlint(
	is_all: true, # 是否检查所有文件，默认 true
	configuration: "Debug", # 构建配置，Debug/Release
	commit_hash: nil # 指定 commit hash，仅检查变更文件
)
```

### 3. 检测重复代码
功能：检测项目中的重复 Swift 代码。
使用前需要参考自定义 .periphery.yml 文件，并将该文件放到项目根目录。

```ruby
detect_duplicity_code(
	is_all: true, # 是否检查所有文件，默认 true
	commit_hash: nil # 指定 commit hash，仅检查变更文件
)
```

### 4. 检测未使用代码
功能：检测项目中未被使用的代码。
默认只支持 Debug，需要支持 Release 请在 Build settings 中将 Enable Index-While-Building Functionality 设置为 Yes。

```ruby
detect_unused_code(
	configuration: "Debug" # 构建配置，Debug/Release
)
```

### 5. 检测未使用图片资源
功能：检测项目中未被使用的图片资源。

```ruby
detect_unused_image()
```

---

## 贡献与支持

如需更多帮助或贡献，请提交 Issue 或 PR。
