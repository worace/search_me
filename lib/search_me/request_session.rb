require "faraday"
require "net/http/post/multipart"
require "json"

module SearchMe
  class RequestSession
    attr_reader :server_address, :index, :index_times, :query_times, :query_results

    def initialize(server_address)
      @server_address = server_address
      @index_times = []
      @query_times = []
      @query_results = {}
      @index = {}
    end

    def build_index!
      start = Time.now
      source_files.each do |f_path|
        filename = f_path.split("/").last
        File.readlines(f_path).each_with_index do |line, l_index|
          line.split(/ |-|—/).each_with_index do |word, w_index|
            word = tokenize(word)
            if index[word].nil?
              index[word] = ["#{filename}:#{l_index + 1}:#{w_index + 1}"]
            else
              index[word] << "#{filename}:#{l_index + 1}:#{w_index + 1}"
            end
          end
        end
      end
      puts "made an index in #{Time.now - start} seconds"
    end

    def tokenize(word)
      word.downcase.gsub(/\W|_/,"")
    end

    def prep
      source_files.each do |f_path|
        start = Time.now
        url = URI.parse("#{server_address}/index")
        File.open(f_path) do |file|
          req = Net::HTTP::Post::Multipart.new url.path,
            "file" => UploadIO.new(file, "text", f_path.split("/").last)
          res = Net::HTTP.start(url.host, url.port) do |http|
            http.request(req)
          end
          puts res
        end
        index_times << (Time.now - start)
      end
    end

    def run_queries
      500.times do
        word = index.keys.sample
        answer = index[word]
        puts "will query against word \"#{word}\""
        puts "and expect result #{answer}"

        start = Time.now
          result = JSON.parse(Faraday.post("#{server_address}/query", {query: word}).body)
        query_times << (Time.now - start)
        query_results[word] = result
      end
    end

    def output_results
      puts "indexed #{source_files.count} files in average of #{index_times.reduce(:+)/index_times.length} seconds"
      puts "performed 100 queries in average of #{query_times.reduce(:+)/query_times.length} seconds"
      correct = []
      incorrect = []
      query_results.each do |word, results|
        if (results - @index[word]).count == 0
          correct << word
        else
          incorrect << word
        end
      end

      puts "correct queries: #{correct.count}"
      puts "incorrect: #{incorrect.count}"
      puts "success ratio: #{incorrect.any? ? (correct.count / incorrect.count) : "100" }%"
    end

    def run
      build_index!
      prep
      run_queries
      output_results
    end

    def source_files
      Dir.glob("./source_files/*.txt")
    end
  end
end

# Prep phase
# 45s ? 60s?
# bronze/silver/gold for index time?
# send N files successively
# contestant must index files
# Search phase
# choose random file random line random word position
# send word
# verify client response match
#
# Throughput/resp time thresholds ??
# bronze / silver / gold?
#
#file = source_files.sample
#lines = File.readlines(file)
#line_index = rand(lines.length)
##puts "words: #{lines[line_index].split}"
#word_index = rand(lines[line_index].split.length).to_i
#word = lines[line_index].split[word_index]
