require_relative "./source_file_list"

module SearchMe
  class Indexer
    attr_reader :index

    def initialize
      @index = {}
    end

    def build_index!
      start = Time.now
      source_files.each do |f_path|
        puts "indexing #{f_path}"
        filename = f_path.split("/").last
        File.readlines(f_path).each_with_index do |line, l_index|
          line.split.each_with_index do |word, w_index|
            if index[word].nil?
              index[word] = ["#{filename}:#{l_index}:#{w_index}"]
            else
              index[word] << "#{filename}:#{l_index}:#{w_index}"
            end
          end
        end
      end
      puts "made an index in #{Time.now - start} seconds"
    end

    def source_files
      SourceFileList.new.files
    end
  end
end

