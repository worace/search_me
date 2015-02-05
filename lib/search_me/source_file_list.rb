module SearchMe
  class SourceFileList
    def files
      Dir.glob(File.join(__dir__, "..", "..", "sanitized_files", "*"))
    end
  end
end
