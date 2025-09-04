require 'fastlane_core/ui/ui'
require 'fileutils'

module Fastlane
  module Helper
    class CommonHelper

      def self.read_cached_txt(file_name)
        if File.exist?(file_name)
          File.read(file_name).strip
        else
          nil
        end
      end

      def self.write_cached_txt(file_name, content)
        dir_name = File.dirname(file_name)
        FileUtils.mkdir_p(dir_name) unless Dir.exist?(dir_name)

        File.open(file_name, "w") { |file| file.write(content) }
      end

      def self.get_cached_build_number
        cached_build = read_cached_txt(Constants.BUILD_NUMBER_FILE)
        currentTime = Time.new.strftime("%Y%m%d")
        
        if cached_build.nil? || cached_build.empty?
          # 初始化 build
          return "#{currentTime}.00"
        else
          return cached_build
        end
      end

      # 判断字段是否有值
      def self.is_validate_string(variable)
        if variable.nil? || variable.empty?
          return false
        end
        return true
      end

      # 获取当前 commit_hash 到最新 commit 下所有变更的 swift 文件
      def self.get_git_modified_swift_files(commit_hash)
        modified_files = sh("git diff --name-only --diff-filter=d #{commit_hash}..origin/develop").split("\n")
        swift_files = modified_files.select { |file| file.end_with?('.swift') }
        return swift_files
      end

      # 缓存最新 git
      def self.cache_git_commit 
        latest_commit = sh("git rev-parse HEAD").strip
        write_cached_txt(COMMIT_HASH_FILE, latest_commit)
      end

      # 从构建日志中提取 index store 路径的辅助方法
      def self.extract_index_store_path(log_file)
        begin
          log_content = File.read(log_file)

          # 在日志中查找 DerivedData 路径
          derived_data_match = log_content.match(/DerivedData\/([^\/]+)-([^\/]+)/)
          if derived_data_match
            project_name = derived_data_match[1]
            hash_suffix = derived_data_match[2]
            
            # 构建可能的 index store 路径
            derived_data_base = File.expand_path("~/Library/Developer/Xcode/DerivedData")
            project_dir = "#{derived_data_base}/#{project_name}-#{hash_suffix}"
            
            # Xcode 14+ 使用 Index.noindex
            index_paths = [
              "#{project_dir}/Index.noindex/DataStore",
              "#{project_dir}/Index/DataStore"
            ]
            
            # 返回第一个存在的路径
            index_paths.each do |path|
              if File.exist?(path)
                puts "*************| 找到 index store: #{path} |*************"
                return path
              end
            end
          end
          
          puts "*************| 在构建日志中未找到有效的 index store 路径 |*************"
          return nil
        rescue => e
          puts "*************| 解析构建日志失败: #{e.message} |*************"
          return nil
        end
      end

      # 生成并打开 html
      def self.generate_and_open_html(title, python_file, origin_file, html_file)
        python_path = File.expand_path("../../python/#{python_file}", __dir__)
        origin_file_path = File.expand_path(origin_file)
        html_file_path = File.expand_path(html_file)

        system("python3 \"#{python_path}\" \"#{title}\" \"#{origin_file_path}\" \"#{html_file_path}\"")
        system("open \"#{html_file_path}\"")

        File.delete(origin_file_path)
      end

    end
  end
end
