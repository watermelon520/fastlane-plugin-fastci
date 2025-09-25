require 'fastlane_core/ui/ui'
require 'fastlane/plugin/fir_cli'
require 'fileutils'

module Fastlane
  module Helper
    class FirHelper

      # def self.get_download_url(download_domain, short)
      #   "https://#{download_domain}/#{short}"
      # end

      # def self.get_qrcode(download_url)
      #   filePath = File.expand_path(Constants.IPA_OUTPUT_DIR)
      #   qrcode_path = "#{filePath}/fir-qrcode.png"
      #   generate_rqrcode(download_url, qrcode_path)

      #   qrcode_path
      # end

      # def self.generate_rqrcode(string, png_file_path)
      #   qrcode = ::RQRCode::QRCode.new(string.to_s)
      #   qrcode.as_png(size: 500, border_modules: 2, file: png_file_path)
      #   png_file_path
      # end

    end
  end
end
