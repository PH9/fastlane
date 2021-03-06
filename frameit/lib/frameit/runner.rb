require 'fastimage'

require_relative 'frame_downloader'
require_relative 'module'
require_relative 'screenshot'
require_relative 'device_types'

module Frameit
  class Runner
    def initialize
      downloader = FrameDownloader.new
      unless downloader.frames_exist?
        downloader.download_frames
      end
    end

    def run(path, color = nil)
      unless color
        color = Frameit::Color::BLACK
        color = Frameit::Color::SILVER if Frameit.config[:white] || Frameit.config[:silver]
        color = Frameit::Color::GOLD if Frameit.config[:gold]
        color = Frameit::Color::ROSE_GOLD if Frameit.config[:rose_gold]
      end

      screenshots = Dir.glob("#{path}/**/*.{png,PNG}").uniq # uniq because thanks to {png,PNG} there are duplicates

      if screenshots.count > 0
        screenshots.each do |full_path|
          next if skip_path?(full_path)

          begin
            screenshot = Screenshot.new(full_path, color)

            next if skip_up_to_date?(screenshot)

            editor = editor(screenshot)

            if editor.should_skip?
              UI.message("Skipping framing of screenshot #{screenshot.path}.  No title provided in your Framefile.json or title.strings.")
            else
              Helper.show_loading_indicator("Framing screenshot '#{full_path}'")
              editor.frame!
            end
          rescue => ex
            UI.error(ex.to_s)
            UI.error("Backtrace:\n\t#{ex.backtrace.join("\n\t")}") if FastlaneCore::Globals.verbose?
          end
        end
      else
        UI.error("Could not find screenshots in current directory: '#{File.expand_path(path)}'")
      end
    end

    def skip_path?(path)
      return true if path.include?("_framed.png")
      return true if path.include?(".itmsp/") # a package file, we don't want to modify that
      return true if path.include?("device_frames/") # these are the device frames the user is using
      device = path.rpartition('/').last.partition('-').first # extract device name
      if device.downcase.include?("watch")
        UI.error("Apple Watch screenshots are not framed: '#{path}'")
        return true # we don't care about watches right now
      end
      false
    end

    def skip_up_to_date?(screenshot)
      if !screenshot.outdated? && Frameit.config[:resume]
        UI.message("Skipping framing of screenshot #{screenshot.path} because its framed file seems up-to-date.")
        return true
      end
      false
    end

    def editor(screenshot)
      if screenshot.mac?
        return MacEditor.new(screenshot)
      else
        return Editor.new(screenshot, Frameit.config[:debug_mode])
      end
    end
  end
end
