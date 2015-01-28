require "faraday"
require 'net/http/post/multipart'

module SearchMe
  class RequestSession
    attr_reader :server_address

    def initialize(server_address)
      @server_address = server_address
    end

    def index
      @index ||= {}
    end

    def build_index
      start = Time.now
      source_files.each do |f_path|
        filename = f_path.split("/").last
        File.readlines(f_path).each_with_index do |line, l_index|
          line.split.each_with_index do |word, w_index|
            if index[word].nil?
              index[word] = ["#{filename}:#{l_index + 1}:#{w_index + 1}"]
            else
              index[word] << ["#{filename}:#{l_index + 1}:#{w_index + 1}"]
            end
          end
        end
      end
      puts "made an index in #{Time.now - start} seconds"
    end

    def prep
      source_files.each do |f_path|
        puts "prep sending file #{f_path}"
        url = URI.parse("#{server_address}/index")
        File.open(f_path) do |file|
          req = Net::HTTP::Post::Multipart.new url.path,
            "file" => UploadIO.new(file, "text", f_path.split("/").last)
          res = Net::HTTP.start(url.host, url.port) do |http|
            http.request(req)
          end
          puts res
        end
      end
    end

    def run_queries
      10.times do
        file = source_files.sample
        lines = File.readlines(file)
        line_index = rand(lines.length)
        #puts "words: #{lines[line_index].split}"
        word_index = rand(lines[line_index].split.length)
        word = lines[line_index].split[word_index]
        puts "will query against word \"#{word}\""
        puts "and expect result file: #{file.split("/").last}, line: #{line_index + 1}, word: #{word_index + 1}"
      end
    end

    def run_session
      prep
      sleep(1)
      run_queries
    end

    def source_files
      Dir.glob("./source_files/*.txt")
    end
  end
end

class SearchRequestSession
end

session = SearchRequestSession.new("http://localhost:9292")
session.build_index
session.prep
session.run_queries

#raise SearchRequestSession.new("localhost:3000").source_files.inspect

# Prep phase
# 45s ? 60s?
# bronze/silver/gold for index time?
# send N files successively
# contestant must index files
#

# Search phase
# choose random file random line random word position
# send word
# verify client response match
#
# Throughput/resp time thresholds ??
# bronze / silver / gold?
#
#
