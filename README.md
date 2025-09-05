
# fastlane-plugin-fastci

一个集成 iOS CI 与多重自动化操作的 Fastlane 集合插件。
简单快速的集成，5 分钟即可上手。

---

## 安装方法

```shell
fastlane add_plugin fastci
```

---

## 使用方法

初始化 fastlane
然后参考目录的 fastlane 文件夹，编写 Fastfile 和 .env.default 文件

然后就可以开始使用了 ` fastlane `

---

## 支持功能与使用示例

### 1. 自动打包
功能：自动编译并导出 ipa 包，支持多种打包方式和集成多项检查。
```ruby
fastci_package(
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
功能：对 Swift 代码进行静态分析，生成分析报告。
```ruby
fastci_analyze_swiftlint(
	is_all: true, # 是否检查所有文件，默认 true
	is_from_package: false, # 是否从打包流程调用，默认 false
	configuration: "Debug", # 构建配置，Debug/Release
	commit_hash: nil # 指定 commit hash，仅检查变更文件
)
```

### 3. 检测重复代码
功能：检测项目中的重复 Swift 代码。
```ruby
fastci_detect_duplicity_code(
	is_all: true, # 是否检查所有文件，默认 true
	commit_hash: nil # 指定 commit hash，仅检查变更文件
)
```

### 4. 检测未使用代码
功能：检测项目中未被引用的 Swift 代码。
```ruby
fastci_detect_unused_code(
	is_from_package: false, # 是否从打包流程调用，默认 false
	configuration: "Debug" # 构建配置，Debug/Release
)
```

### 5. 检测未使用图片资源
功能：检测项目中未被使用的图片资源。
```ruby
fastci_detect_unused_image()
```

---

## 贡献与支持

如需更多帮助或贡献，请提交 Issue 或 PR。
